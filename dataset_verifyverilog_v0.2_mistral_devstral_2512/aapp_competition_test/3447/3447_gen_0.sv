module sms_typing_optimizer(
    input clk,
    input rst_n,
    input start,
    input [7:0] dict_size,
    input [7:0] dict_words [0:7][0:7],
    input [7:0] dict_lens [0:7],
    input [7:0] target [0:15],
    input [7:0] target_len,
    output reg [31:0] min_presses,
    output reg done,
    output reg [255:0] debug_path
);

    // State definitions
    typedef enum logic [1:0] {
        IDLE,
        PREPROCESS,
        DP_COMPUTE