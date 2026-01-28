module BulbasaurCounter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] char_in,
    input wire char_valid,
    input wire char_last,
    output reg [7:0] result,
    output reg done,
    output reg idle
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] PROCESS   = 3'd1;
    localparam [2:0] CALCULATE = 3'd2;
    localparam [2:0] DONE_STATE = 3'd3;

    reg [2:0] state, next_state;

    // Character counters (8-bit each)
    reg [7:0] count_B;
    reg [7:0] count_u;
    reg [7:0] count_l;
    reg [7:0] count_b;
    reg [7:0] count_a;
    reg [7:0] count_s;
    reg [7:0] count_r;

    // ASCII values
    localparam [7:0] ASCII_B = 8'd66;  // 'B'
    localparam [7:0] ASCII_u = 8'd117; // 'u'
    localparam [7:0] ASCII_l = 8'd108; // 'l'
    localparam [7:0] ASCII_b = 8'd98;  // 'b'
    localparam [7:0] ASCII_a = 8'd97;  // 'a'
    localparam [7:0] ASCII_s = 8'd115; // 's'
    localparam [7:0] ASCII_r = 8'd114; // 'r'

    // Calculation variables
    reg [7:0] min_val;
    reg [7:0] temp_min;
    reg [3:0] calc_step;
    localparam [3:0] MAX_CALC_STEPS = 4'd7;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            
            // Reset all counters
            count_B <= 8'd0;
            count_u <= 8'd0;
            count_l <= 8'd0;
            count_b <= 8'd0;
            count_a <= 8'd0;
            count_s <= 8'd0;
            count_r <= 8'd0;
            
            // Reset calculation variables
            min_val <= 8'd0;
            temp_min <= 8'd0;
            calc_step <= 4'd0;
            
            // Reset outputs
            result <= 8'd0;
            done <= 1'b0;
            idle <= 1'b1;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    idle <= 1'b1;
                    done <= 1'b0;
                    if (start) begin
                        // Reset counters on start
                        count_B <= 8'd0;
                        count_u <= 8'd0;
                        count_l <= 8'd0;
                        count_b <= 8'd0;
                        count_a <= 8'd0;
                        count_s <= 8'd0;
                        count_r <= 8'd0;
                        
                        next_state <= PROCESS;
                        idle <= 1'b0;
                    end
                end

                PROCESS: begin
                    idle <= 1'b0;
                    done <= 1'b0;
                    
                    // Increment counters based on character
                    if (char_valid) begin
                        if (char_in == ASCII_B) count_B <= count_B + 8'd1;
                        else if (char_in == ASCII_u) count_u <= count_u + 8'd1;
                        else if (char_in == ASCII_l) count_l <= count_l + 8'd1;
                        else if (char_in == ASCII_b) count_b <= count_b + 8'd1;
                        else if (char_in == ASCII_a) count_a <= count_a + 8'd1;
                        else if (char_in == ASCII_s) count_s <= count_s + 8'd1;
                        else if (char_in == ASCII_r) count_r <= count_r + 8'd1;
                    end
                    
                    // Check for last character
                    if (char_last) begin
                        next_state <= CALCULATE;
                        calc_step <= 4'd0;
                        min_val <= 8'd0;
                    end
                end

                CALCULATE: begin
                    idle <= 1'b0;
                    done <= 1'b0;
                    
                    // Perform min calculation step by step
                    case (calc_step)
                        4'd0: begin
                            temp_min <= count_B;
                            calc_step <= calc_step + 4'd1;
                        end
                        4'd1: begin
                            if (count_u >> 1 < temp_min) temp_min <= count_u >> 1;
                            calc_step <= calc_step + 4'd1;
                        end
                        4'd2: begin
                            if (count_l < temp_min) temp_min <= count_l;
                            calc_step <= calc_step + 4'd1;
                        end
                        4'd3: begin
                            if (count_b < temp_min) temp_min <= count_b;
                            calc_step <= calc_step + 4'd1;
                        end
                        4'd4: begin
                            if (count_a >> 1 < temp_min) temp_min <= count_a >> 1;
                            calc_step <= calc_step + 4'd1;
                        end
                        4'd5: begin
                            if (count_s < temp_min) temp_min <= count_s;
                            calc_step <= calc_step + 4'd1;
                        end
                        4'd6: begin
                            if (count_r < temp_min) temp_min <= count_r;
                            min_val <= temp_min;
                            calc_step <= calc_step + 4'd1;
                        end
                        default: begin
                            next_state <= DONE_STATE;
                        end
                    endcase
                end

                DONE_STATE: begin
                    idle <= 1'b0;
                    result <= min_val;
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                end
            endcase
        end
    end

endmodule