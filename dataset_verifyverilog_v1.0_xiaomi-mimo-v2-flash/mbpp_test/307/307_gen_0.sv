module colon_tuplex (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] tuplex_str_0,
    input wire [7:0] tuplex_str_1,
    input wire [7:0] tuplex_str_2,
    input wire [7:0] tuplex_str_3,
    input wire [7:0] tuplex_str_4,
    input wire [7:0] tuplex_str_5,
    input wire [7:0] tuplex_str_6,
    input wire [7:0] tuplex_str_7,
    input wire [7:0] tuplex_int,
    input wire [7:0] tuplex_list_0,
    input wire [7:0] tuplex_list_1,
    input wire [7:0] tuplex_list_2,
    input wire [7:0] tuplex_list_3,
    input wire tuplex_bool,
    input wire [1:0] m,
    input wire [7:0] n,
    output reg [7:0] result_str_0,
    output reg [7:0] result_str_1,
    output reg [7:0] result_str_2,
    output reg [7:0] result_str_3,
    output reg [7:0] result_str_4,
    output reg [7:0] result_str_5,
    output reg [7:0] result_str_6,
    output reg [7:0] result_str_7,
    output reg [7:0] result_int,
    output reg [7:0] result_list_0,
    output reg [7:0] result_list_1,
    output reg [7:0] result_list_2,
    output reg [7:0] result_list_3,
    output reg result_bool,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] PROCESS = 2'd1;
    localparam [1:0] FINISH  = 2'd2;

    reg [1:0] state;
    reg [1:0] next_state;

    // Control signals
    reg load_result;
    reg set_done;

    // Combinational logic for next state
    always @(*) begin
        next_state = IDLE; // Default
        load_result = 1'b0;
        set_done = 1'b0;
        
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = PROCESS;
                    load_result = 1'b1;
                end else begin
                    next_state = IDLE;
                end
            end
            
            PROCESS: begin
                next_state = FINISH;
                set_done = 1'b1;
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            // Initialize all outputs to avoid X
            result_str_0 <= 8'd0;
            result_str_1 <= 8'd0;
            result_str_2 <= 8'd0;
            result_str_3 <= 8'd0;
            result_str_4 <= 8'd0;
            result_str_5 <= 8'd0;
            result_str_6 <= 8'd0;
            result_str_7 <= 8'd0;
            result_int <= 8'd0;
            result_list_0 <= 8'd0;
            result_list_1 <= 8'd0;
            result_list_2 <= 8'd0;
            result_list_3 <= 8'd0;
            result_bool <= 1'b0;
        end else begin
            state <= next_state;
            
            if (load_result) begin
                // Copy string elements
                result_str_0 <= tuplex_str_0;
                result_str_1 <= tuplex_str_1;
                result_str_2 <= tuplex_str_2;
                result_str_3 <= tuplex_str_3;
                result_str_4 <= tuplex_str_4;
                result_str_5 <= tuplex_str_5;
                result_str_6 <= tuplex_str_6;
                result_str_7 <= tuplex_str_7;
                
                // Copy int and bool
                result_int <= tuplex_int;
                result_bool <= tuplex_bool;
                
                // Handle list modification based on index m
                if (m == 2'd2) begin
                    // Append logic: shift left, set last to n
                    result_list_0 <= tuplex_list_1;
                    result_list_1 <= tuplex_list_2;
                    result_list_2 <= tuplex_list_3;
                    result_list_3 <= n;
                end else begin
                    // Copy list as is (m != 2)
                    result_list_0 <= tuplex_list_0;
                    result_list_1 <= tuplex_list_1;
                    result_list_2 <= tuplex_list_2;
                    result_list_3 <= tuplex_list_3;
                end
            end
            
            // Done signal handling
            if (set_done) begin
                done <= 1'b1;
            end else begin
                done <= 1'b0;
            end
        end
    end
endmodule