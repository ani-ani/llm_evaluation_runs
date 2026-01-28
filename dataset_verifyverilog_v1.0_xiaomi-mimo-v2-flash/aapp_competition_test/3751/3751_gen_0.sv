module ValidateObfuscation (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] char_in,
    input wire valid_in,
    input wire done_in,
    output reg result,
    output reg ready,
    output reg busy,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] RECEIVING  = 3'd1;
    localparam [2:0] VALIDATING = 3'd2;
    localparam [2:0] COMPLETE   = 3'd3;
    localparam [2:0] ERROR      = 3'd4;
    localparam [2:0] DONE_STATE = 3'd5;

    // Registers for tracking first positions (9 bits each, 0-500)
    reg [8:0] first_pos_a, first_pos_b, first_pos_c, first_pos_d, first_pos_e;
    reg [8:0] first_pos_f, first_pos_g, first_pos_h, first_pos_i, first_pos_j;
    reg [8:0] first_pos_k, first_pos_l, first_pos_m, first_pos_n, first_pos_o;
    reg [8:0] first_pos_p, first_pos_q, first_pos_r, first_pos_s, first_pos_t;
    reg [8:0] first_pos_u, first_pos_v, first_pos_w, first_pos_x, first_pos_y;
    reg [8:0] first_pos_z;

    // 26-bit flag register to track which letters have appeared
    reg [25:0] letters_seen;

    // Counters
    reg [8:0] char_counter;      // 0-500
    reg [8:0] total_chars;        // Total characters received
    reg [4:0] check_idx;          // 0-25 for alphabet position
    reg [9:0] cycle_counter;      // For timeout (0-1023)
    localparam [9:0] MAX_CYCLES = 10'd1000;

    // State machine
    reg [2:0] state, next_state;

    // Helper to get position for a letter index
    function automatic [8:0] get_pos;
        input [4:0] idx;
        case (idx)
            5'd0:  get_pos = first_pos_a;
            5'd1:  get_pos = first_pos_b;
            5'd2:  get_pos = first_pos_c;
            5'd3:  get_pos = first_pos_d;
            5'd4:  get_pos = first_pos_e;
            5'd5:  get_pos = first_pos_f;
            5'd6:  get_pos = first_pos_g;
            5'd7:  get_pos = first_pos_h;
            5'd8:  get_pos = first_pos_i;
            5'd9:  get_pos = first_pos_j;
            5'd10: get_pos = first_pos_k;
            5'd11: get_pos = first_pos_l;
            5'd12: get_pos = first_pos_m;
            5'd13: get_pos = first_pos_n;
            5'd14: get_pos = first_pos_o;
            5'd15: get_pos = first_pos_p;
            5'd16: get_pos = first_pos_q;
            5'd17: get_pos = first_pos_r;
            5'd18: get_pos = first_pos_s;
            5'd19: get_pos = first_pos_t;
            5'd20: get_pos = first_pos_u;
            5'd21: get_pos = first_pos_v;
            5'd22: get_pos = first_pos_w;
            5'd23: get_pos = first_pos_x;
            5'd24: get_pos = first_pos_y;
            5'd25: get_pos = first_pos_z;
            default: get_pos = 9'd0;
        endcase
    endfunction

    // Combinational logic for ready
    always @(*) begin
        ready = (state == IDLE) && !start;
    end

    // Sequential logic for state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            busy <= 1'b0;
            done <= 1'b0;
            char_counter <= 9'd0;
            total_chars <= 9'd0;
            check_idx <= 5'd0;
            cycle_counter <= 10'd0;
            letters_seen <= 26'd0;
            first_pos_a  <= 9'd501;
            first_pos_b  <= 9'd501;
            first_pos_c  <= 9'd501;
            first_pos_d  <= 9'd501;
            first_pos_e  <= 9'd501;
            first_pos_f  <= 9'd501;
            first_pos_g  <= 9'd501;
            first_pos_h  <= 9'd501;
            first_pos_i  <= 9'd501;
            first_pos_j  <= 9'd501;
            first_pos_k  <= 9'd501;
            first_pos_l  <= 9'd501;
            first_pos_m  <= 9'd501;
            first_pos_n  <= 9'd501;
            first_pos_o  <= 9'd501;
            first_pos_p  <= 9'd501;
            first_pos_q  <= 9'd501;
            first_pos_r  <= 9'd501;
            first_pos_s  <= 9'd501;
            first_pos_t  <= 9'd501;
            first_pos_u  <= 9'd501;
            first_pos_v  <= 9'd501;
            first_pos_w  <= 9'd501;
            first_pos_x  <= 9'd501;
            first_pos_y  <= 9'd501;
            first_pos_z  <= 9'd501;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    busy <= 1'b0;
                    if (start) begin
                        state <= RECEIVING;
                        busy <= 1'b1;
                        char_counter <= 9'd0;
                        total_chars <= 9'd0;
                        check_idx <= 5'd0;
                        cycle_counter <= 10'd0;
                        letters_seen <= 26'd0;
                        first_pos_a  <= 9'd501;
                        first_pos_b  <= 9'd501;
                        first_pos_c  <= 9'd501;
                        first_pos_d  <= 9'd501;
                        first_pos_e  <= 9'd501;
                        first_pos_f  <= 9'd501;
                        first_pos_g  <= 9'd501;
                        first_pos_h  <= 9'd501;
                        first_pos_i  <= 9'd501;
                        first_pos_j  <= 9'd501;
                        first_pos_k  <= 9'd501;
                        first_pos_l  <= 9'd501;
                        first_pos_m  <= 9'd501;
                        first_pos_n  <= 9'd501;
                        first_pos_o  <= 9'd501;
                        first_pos_p  <= 9'd501;
                        first_pos_q  <= 9'd501;
                        first_pos_r  <= 9'd501;
                        first_pos_s  <= 9'd501;
                        first_pos_t  <= 9'd501;
                        first_pos_u  <= 9'd501;
                        first_pos_v  <= 9'd501;
                        first_pos_w  <= 9'd501;
                        first_pos_x  <= 9'd501;
                        first_pos_y  <= 9'd501;
                        first_pos_z  <= 9'd501;
                    end
                end

                RECEIVING: begin
                    cycle_counter <= cycle_counter + 10'd1;
                    if (cycle_counter >= MAX_CYCLES) begin
                        state <= ERROR;
                    end else if (valid_in) begin
                        // Process character
                        if (char_in >= 8'd97 && char_in <= 8'd122) begin
                            letters_seen[char_in - 8'd97] <= 1'b1;
                            // Only set first position if not already set
                            case (char_in)
                                8'd97: begin if (first_pos_a > 9'd500) first_pos_a <= char_counter; end
                                8'd98: begin if (first_pos_b > 9'd500) first_pos_b <= char_counter; end
                                8'd99: begin if (first_pos_c > 9'd500) first_pos_c <= char_counter; end
                                8'd100: begin if (first_pos_d > 9'd500) first_pos_d <= char_counter; end
                                8'd101: begin if (first_pos_e > 9'd500) first_pos_e <= char_counter; end
                                8'd102: begin if (first_pos_f > 9'd500) first_pos_f <= char_counter; end
                                8'd103: begin if (first_pos_g > 9'd500) first_pos_g <= char_counter; end
                                8'd104: begin if (first_pos_h > 9'd500) first_pos_h <= char_counter; end
                                8'd105: begin if (first_pos_i > 9'd500) first_pos_i <= char_counter; end
                                8'd106: begin if (first_pos_j > 9'd500) first_pos_j <= char_counter; end
                                8'd107: begin if (first_pos_k > 9'd500) first_pos_k <= char_counter; end
                                8'd108: begin if (first_pos_l > 9'd500) first_pos_l <= char_counter; end
                                8'd109: begin if (first_pos_m > 9'd500) first_pos_m <= char_counter; end
                                8'd110: begin if (first_pos_n > 9'd500) first_pos_n <= char_counter; end
                                8'd111: begin if (first_pos_o > 9'd500) first_pos_o <= char_counter; end
                                8'd112: begin if (first_pos_p > 9'd500) first_pos_p <= char_counter; end
                                8'd113: begin if (first_pos_q > 9'd500) first_pos_q <= char_counter; end
                                8'd114: begin if (first_pos_r > 9'd500) first_pos_r <= char_counter; end
                                8'd115: begin if (first_pos_s > 9'd500) first_pos_s <= char_counter; end
                                8'd116: begin if (first_pos_t > 9'd500) first_pos_t <= char_counter; end
                                8'd117: begin if (first_pos_u > 9'd500) first_pos_u <= char_counter; end
                                8'd118: begin if (first_pos_v > 9'd500) first_pos_v <= char_counter; end
                                8'd119: begin if (first_pos_w > 9'd500) first_pos_w <= char_counter; end
                                8'd120: begin if (first_pos_x > 9'd500) first_pos_x <= char_counter; end
                                8'd121: begin if (first_pos_y > 9'd500) first_pos_y <= char_counter; end
                                8'd122: begin if (first_pos_z > 9'd500) first_pos_z <= char_counter; end
                                default: begin end
                            endcase
                            char_counter <= char_counter + 9'd1;
                        end
                    end else if (done_in) begin
                        total_chars <= char_counter;
                        state <= VALIDATING;
                        check_idx <= 5'd0;
                        cycle_counter <= 10'd0;
                    end
                end

                VALIDATING: begin
                    cycle_counter <= cycle_counter + 10'd1;
                    if (cycle_counter >= MAX_CYCLES) begin
                        state <= ERROR;
                    end else begin
                        if (check_idx < 5'd26) begin
                            // Check if this letter is in contiguous prefix
                            if (letters_seen[check_idx]) begin
                                // Check if this is the first letter that appeared
                                if (check_idx == 5'd0) begin
                                    // First letter must be 'a' (letter index 0)
                                    if (first_pos_a > 9'd500) begin
                                        // 'a' never appeared, invalid
                                        state <= ERROR;
                                    end
                                end else begin
                                    // Check if previous letter appeared
                                    if (!letters_seen[check_idx - 5'd1]) begin
                                        // Gap detected
                                        state <= ERROR;
                                    end else begin
                                        // Check position ordering
                                        if (get_pos(check_idx - 5'd1) >= get_pos(check_idx)) begin
                                            state <= ERROR;
                                        end
                                    end
                                end
                            end
                            check_idx <= check_idx + 5'd1;
                        end else begin
                            // All letters checked, validation passed
                            state <= COMPLETE;
                        end
                    end
                end

                COMPLETE: begin
                    result <= 1'b1;
                    done <= 1'b1;
                    state <= DONE_STATE;
                end

                ERROR: begin
                    result <= 1'b0;
                    done <= 1'b1;
                    state <= DONE_STATE;
                end

                DONE_STATE: begin
                    done <= 1'b0;
                    busy <= 1'b0;
                    if (!start) begin
                        state <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule