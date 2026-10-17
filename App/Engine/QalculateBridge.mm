#import "QalculateBridge.h"
#include <libqalculate/qalculate.h>
#include <mutex>

@implementation QCalculationResult
- (instancetype)init {
    if ((self = [super init])) { _text = @""; _latex = @""; _inputLatex = @""; _warnings = @[]; }
    return self;
}
@end

@implementation QalculateBridge
- (QCalculationResult *)evaluate:(NSString *)expression exact:(BOOL)exact degrees:(BOOL)degrees {
    static std::mutex lock;
    std::lock_guard<std::mutex> guard(lock); // libqalculate has process-global state.
    static Calculator *calculator = nullptr;
    static bool definitionsLoaded = false;
    QCalculationResult *response = [QCalculationResult new];
    if (!calculator) {
        NSURL *definitions = [NSBundle.mainBundle URLForResource:@"Definitions" withExtension:nil];
        if (!definitions) { response.error = @"The bundled calculator definitions are missing."; return response; }
        setenv("QALCULATE_DEFINITIONS_DIR", definitions.path.UTF8String, 1);
        calculator = new Calculator(true);
        calculator->setPrecision(30);
        definitionsLoaded = calculator->loadGlobalDefinitions();
        calculator->clearMessages();
    }
    if (!definitionsLoaded) { response.error = @"The calculator definitions could not be loaded."; return response; }
    if (expression.length == 0 || expression.length > 4096) {
        response.error = @"Enter an expression of 1–4096 characters."; return response;
    }
    calculator->clearMessages();
    EvaluationOptions evaluation = default_user_evaluation_options;
    evaluation.approximation = exact ? APPROXIMATION_TRY_EXACT : APPROXIMATION_APPROXIMATE;
    evaluation.parse_options.angle_unit = degrees ? ANGLE_UNIT_DEGREES : ANGLE_UNIT_RADIANS;
    PrintOptions output = default_print_options;
    output.number_fraction_format = exact ? FRACTION_FRACTIONAL : FRACTION_DECIMAL;
    output.use_unicode_signs = true;
    MathStructure result, parsed;
    bool completed = calculator->calculate(&result, expression.UTF8String, 3000, evaluation, &parsed);
    NSMutableArray<NSString *> *warnings = [NSMutableArray array];
    while (calculator->message()) {
        NSString *message = [NSString stringWithUTF8String:calculator->message()->message().c_str()] ?: @"Calculation error";
        if (calculator->message()->type() == MESSAGE_ERROR) response.error = message;
        else [warnings addObject:message];
        calculator->nextMessage();
    }
    if (!completed) { response.error = @"Calculation took too long. Try a simpler expression."; return response; }
    if (response.error) return response;
    if (result.isUndefined()) { response.error = @"This expression has no defined result."; return response; }
    response.text = [NSString stringWithUTF8String:calculator->print(result, 1000, output).c_str()] ?: @"";
    response.latex = [NSString stringWithUTF8String:calculator->print(result, 1000, output, true, 0, TAG_TYPE_LATEX).c_str()] ?: @"";
    response.inputLatex = [NSString stringWithUTF8String:calculator->print(parsed, 1000, output, true, 0, TAG_TYPE_LATEX).c_str()] ?: expression;
    response.approximate = result.isApproximate();
    response.warnings = warnings;
    if (response.text.length == 0 || calculator->aborted()) response.error = @"The result is too large to display.";
    return response;
}
@end
