module bulbasaur_counter (
    input clk,
    input rst_n,
    input start,
    input [127:0] str_input,
    input [7:0] str_len,
    output reg [7:0] result,
    output reg done
);

    // State encoding
    localparam IDLE = 3'b001;
    localparam COUNTING = 3'b010;
    localparam COMPUTING = 3'b100;
    // The DONE state is not explicitly required for logic but used for the done signal.
    // We will use the 'done' register to hold the done state.

    reg [2:0] state;
    reg [7:0] idx;           // Current byte index (0-15)
    reg [7:0] count_B;       // Count of 'B'
    reg [7:0] count_u;       // Count of 'u'
    reg [7:0] count_l;       // Count of 'l'
    reg [7:0] count_b;       // Count of 'b'
    reg [7:0] count_a;       // Count of 'a'
    reg [7:0] count_s;       // Count of 's'
    reg [7:0] count_r;       // Count of 'r'

    // Helper signals for computation
    wire [7:0] half_u = count_u >> 1;
    wire [7:0] half_a = count_a >> 1;
    wire [7:0] min1 = (count_B < half_u) ? count_B : half_u;
    wire [7:0] min2 = (count_l < count_b) ? count_l : count_b;
    wire [7:0] min3 = (half_a < count_s) ? half_a : count_s;
    wire [7:0] min4 = (min2 < count_r) ? min2 : count_r;
    wire [7:0] min13 = (min1 < min3) ? min1 : min3;
    wire [7:0] min_final = (min13 < min4) ? min13 : min4;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 8'b0;
            idx <= 8'b0;
            count_B <= 8'b0;
            count_u <= 8'b0;
            count_l <= 8'b0;
            count_b <= 8'b0;
            count_a <= 8'b0;
            count_s <= 8'b0;
            count_r <= 8'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= COUNTING;
                        idx <= 8'b0;
                        count_B <= 8'b0;
                        count_u <= 8'b0;
                        count_l <= 8'b0;
                        count_b <= 8'b0;
                        count_a <= 8'b0;
                        count_s <= 8'b0;
                        count_r <= 8'b0;
                    end
                end

                COUNTING: begin
                    if (idx < str_len && idx < 16) begin
                        // Extract current byte based on index
                        // str_input[7:0] is char 0, str_input[15:8] is char 1, etc.
                        // So byte i is at [8*i + 7 : 8*i]
                        case (str_input[8*idx +: 8])
                            8'h42: count_B <= count_B + 1; // 'B'
                            8'h75: count_u <= count_u + 1; // 'u'
                            8'h6C: count_l <= count_l + 1; // 'l'
                            8'h62: count_b <= count_b + 1; // 'b'
                            8'h61: count_a <= count_a + 1; // 'a'
                            8'h73: count_s <= count_s + 1; // 's'
                            8'h72: count_r <= count_r + 1; // 'r'
                            default: begin end
                        endcase
                        idx <= idx + 1;
                    end else begin
                        state <= COMPUTING;
                    end
                end

                COMPUTING: begin
                    // Calculation happens combinationally on min_final
                    result <= min_final;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule