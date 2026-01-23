module count_bulbasaurs (
    input clk,
    input rst_n,
    input start,
    input [15:0][7:0] char_array,
    input [3:0] valid_length,
    output reg [3:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COUNT_CHAR = 3'd1;
    localparam [2:0] CALC_RESULT = 3'd2;
    localparam [2:0] FINISH = 3'd3;

    // Internal registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [3:0] idx;
    reg [3:0] count_B;
    reg [3:0] count_u;
    reg [3:0] count_l;
    reg [3:0] count_b;
    reg [3:0] count_a;
    reg [3:0] count_s;
    reg [3:0] count_r;
    reg [3:0] calc_count;
    reg [3:0] temp_result;
    reg [3:0] calc_count_div2;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next state and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 4'd0;
            done <= 1'b0;
            idx <= 4'd0;
            count_B <= 4'd0;
            count_u <= 4'd0;
            count_l <= 4'd0;
            count_b <= 4'd0;
            count_a <= 4'd0;
            count_s <= 4'd0;
            count_r <= 4'd0;
            calc_count <= 4'd0;
            temp_result <= 4'd0;
            calc_count_div2 <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= COUNT_CHAR;
                        idx <= 4'd0;
                        count_B <= 4'd0;
                        count_u <= 4'd0;
                        count_l <= 4'd0;
                        count_b <= 4'd0;
                        count_a <= 4'd0;
                        count_s <= 4'd0;
                        count_r <= 4'd0;
                    end
                end

                COUNT_CHAR: begin
                    if (idx < valid_length) begin
                        // Process current character
                        case (char_array[idx])
                            8'd66: count_B <= count_B + 4'd1;   // 'B'
                            8'd117: count_u <= count_u + 4'd1;  // 'u'
                            8'd108: count_l <= count_l + 4'd1;  // 'l'
                            8'd98: count_b <= count_b + 4'd1;   // 'b'
                            8'd97: count_a <= count_a + 4'd1;   // 'a'
                            8'd115: count_s <= count_s + 4'd1;  // 's'
                            8'd114: count_r <= count_r + 4'd1;  // 'r'
                            default: begin end
                        endcase
                        idx <= idx + 4'd1;
                    end else begin
                        state <= CALC_RESULT;
                        calc_count <= 4'd0;
                        calc_count_div2 <= 4'd0;
                        temp_result <= 4'd15; // Initialize with max
                    end
                end

                CALC_RESULT: begin
                    // Calculate count//2 for 'u' and 'a'
                    case (calc_count)
                        4'd0: begin // Check B
                            if (count_B < temp_result) begin
                                temp_result <= count_B;
                            end
                            calc_count <= calc_count + 4'd1;
                        end
                        4'd1: begin // Check u//2
                            calc_count_div2 <= count_u >> 1; // Divide by 2
                            if (calc_count_div2 < temp_result) begin
                                temp_result <= calc_count_div2;
                            end
                            calc_count <= calc_count + 4'd1;
                        end
                        4'd2: begin // Check l
                            if (count_l < temp_result) begin
                                temp_result <= count_l;
                            end
                            calc_count <= calc_count + 4'd1;
                        end
                        4'd3: begin // Check b
                            if (count_b < temp_result) begin
                                temp_result <= count_b;
                            end
                            calc_count <= calc_count + 4'd1;
                        end
                        4'd4: begin // Check a//2
                            calc_count_div2 <= count_a >> 1; // Divide by 2
                            if (calc_count_div2 < temp_result) begin
                                temp_result <= calc_count_div2;
                            end
                            calc_count <= calc_count + 4'd1;
                        end
                        4'd5: begin // Check s
                            if (count_s < temp_result) begin
                                temp_result <= count_s;
                            end
                            calc_count <= calc_count + 4'd1;
                        end
                        4'd6: begin // Check r
                            if (count_r < temp_result) begin
                                temp_result <= count_r;
                            end
                            state <= FINISH;
                        end
                    endcase
                end

                FINISH: begin
                    result <= temp_result;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule