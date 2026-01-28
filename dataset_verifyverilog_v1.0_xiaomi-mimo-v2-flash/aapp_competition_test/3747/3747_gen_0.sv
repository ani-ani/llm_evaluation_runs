module word_counter (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] char_in,
    input wire char_valid,
    input wire char_last,
    output reg [7:0] result,
    output reg done,
    output wire idle
);

    // ASCII constants
    localparam [7:0] ASCII_B = 8'h42;
    localparam [7:0] ASCII_u = 8'h75;
    localparam [7:0] ASCII_l = 8'h6C;
    localparam [7:0] ASCII_b = 8'h62;
    localparam [7:0] ASCII_a = 8'h61;
    localparam [7:0] ASCII_s = 8'h73;
    localparam [7:0] ASCII_r = 8'h72;

    // State definitions
    localparam [1:0] IDLE_STATE = 2'd0;
    localparam [1:0] PROCESSING_STATE = 2'd1;
    localparam [1:0] CALCULATING_STATE = 2'd2;
    localparam [1:0] DONE_STATE = 2'd3;

    // State and control registers
    reg [1:0] state;
    reg [1:0] next_state;
    reg [7:0] count_B;
    reg [7:0] count_u;
    reg [7:0] count_l;
    reg [7:0] count_b;
    reg [7:0] count_a;
    reg [7:0] count_s;
    reg [7:0] count_r;
    reg [7:0] calc_step;
    reg [7:0] min_val;
    reg [7:0] temp_val;
    reg [7:0] shift_temp;
    reg [3:0] calc_cycle;

    // Combinational logic for min calculations
    reg [7:0] next_min;
    reg [7:0] current_compare;

    // Output assignments
    assign idle = (state == IDLE_STATE);

    // State transition logic
    always @(*) begin
        case (state)
            IDLE_STATE: begin
                if (start)
                    next_state = PROCESSING_STATE;
                else
                    next_state = IDLE_STATE;
            end
            PROCESSING_STATE: begin
                if (char_last && char_valid)
                    next_state = CALCULATING_STATE;
                else
                    next_state = PROCESSING_STATE;
            end
            CALCULATING_STATE: begin
                if (calc_cycle >= 4'd10)
                    next_state = DONE_STATE;
                else
                    next_state = CALCULATING_STATE;
            end
            DONE_STATE: begin
                next_state = IDLE_STATE;
            end
            default: next_state = IDLE_STATE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE_STATE;
            count_B <= 8'd0;
            count_u <= 8'd0;
            count_l <= 8'd0;
            count_b <= 8'd0;
            count_a <= 8'd0;
            count_s <= 8'd0;
            count_r <= 8'd0;
            result <= 8'd0;
            done <= 1'b0;
            calc_step <= 8'd0;
            min_val <= 8'd0;
            temp_val <= 8'd0;
            shift_temp <= 8'd0;
            calc_cycle <= 4'd0;
        end else begin
            state <= next_state;
            done <= 1'b0;

            case (state)
                IDLE_STATE: begin
                    if (start) begin
                        count_B <= 8'd0;
                        count_u <= 8'd0;
                        count_l <= 8'd0;
                        count_b <= 8'd0;
                        count_a <= 8'd0;
                        count_s <= 8'd0;
                        count_r <= 8'd0;
                        calc_step <= 8'd0;
                        min_val <= 8'd0;
                        temp_val <= 8'd0;
                        shift_temp <= 8'd0;
                        calc_cycle <= 4'd0;
                    end
                end

                PROCESSING_STATE: begin
                    if (char_valid) begin
                        if (char_in == ASCII_B)
                            count_B <= count_B + 8'd1;
                        else if (char_in == ASCII_u)
                            count_u <= count_u + 8'd1;
                        else if (char_in == ASCII_l)
                            count_l <= count_l + 8'd1;
                        else if (char_in == ASCII_b)
                            count_b <= count_b + 8'd1;
                        else if (char_in == ASCII_a)
                            count_a <= count_a + 8'd1;
                        else if (char_in == ASCII_s)
                            count_s <= count_s + 8'd1;
                        else if (char_in == ASCII_r)
                            count_r <= count_r + 8'd1;
                    end
                end

                CALCULATING_STATE: begin
                    calc_cycle <= calc_cycle + 4'd1;
                    
                    case (calc_step)
                        8'd0: begin
                            min_val <= count_B;
                            calc_step <= 8'd1;
                        end
                        8'd1: begin
                            shift_temp <= count_u >> 1;
                            calc_step <= 8'd2;
                        end
                        8'd2: begin
                            if (shift_temp < min_val)
                                min_val <= shift_temp;
                            calc_step <= 8'd3;
                        end
                        8'd3: begin
                            if (count_l < min_val)
                                min_val <= count_l;
                            calc_step <= 8'd4;
                        end
                        8'd4: begin
                            if (count_b < min_val)
                                min_val <= count_b;
                            calc_step <= 8'd5;
                        end
                        8'd5: begin
                            shift_temp <= count_a >> 1;
                            calc_step <= 8'd6;
                        end
                        8'd6: begin
                            if (shift_temp < min_val)
                                min_val <= shift_temp;
                            calc_step <= 8'd7;
                        end
                        8'd7: begin
                            if (count_s < min_val)
                                min_val <= count_s;
                            calc_step <= 8'd8;
                        end
                        8'd8: begin
                            if (count_r < min_val)
                                min_val <= count_r;
                            calc_step <= 8'd9;
                        end
                        8'd9: begin
                            result <= min_val;
                            calc_step <= 8'd10;
                        end
                        default: begin
                            calc_step <= calc_step;
                        end
                    endcase
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    calc_cycle <= 4'd0;
                    calc_step <= 8'd0;
                end

                default: begin
                    state <= IDLE_STATE;
                end
            endcase
        end
    end

endmodule