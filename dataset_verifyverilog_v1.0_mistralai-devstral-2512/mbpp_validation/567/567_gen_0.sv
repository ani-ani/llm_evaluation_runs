module array_sorted_checker(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr_0,
    input wire [7:0] arr_1,
    input wire [7:0] arr_2,
    input wire [7:0] arr_3,
    input wire [7:0] arr_4,
    input wire [7:0] arr_5,
    input wire [7:0] arr_6,
    input wire [7:0] arr_7,
    input wire [3:0] len,
    output reg result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPARE = 3'd1;
    localparam [2:0] FINISH = 3'd2;

    reg [2:0] state;
    reg [3:0] index;
    reg [7:0] current;
    reg [7:0] next;
    reg [3:0] cycle_count;
    localparam [3:0] MAX_CYCLES = 4'd20;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 4'd0;
            result <= 1'b0;
            done <= 1'b0;
            cycle_count <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 4'd0;
                    if (start) begin
                        state <= COMPARE;
                        index <= 4'd0;
                        result <= 1'b1;  // Assume sorted until proven otherwise
                    end
                end

                COMPARE: begin
                    cycle_count <= cycle_count + 4'd1;

                    // Select current and next elements based on index
                    case (index)
                        4'd0: begin current = arr_0; next = arr_1; end
                        4'd1: begin current = arr_1; next = arr_2; end
                        4'd2: begin current = arr_2; next = arr_3; end
                        4'd3: begin current = arr_3; next = arr_4; end
                        4'd4: begin current = arr_4; next = arr_5; end
                        4'd5: begin current = arr_5; next = arr_6; end
                        4'd6: begin current = arr_6; next = arr_7; end
                        default: begin current = 8'd0; next = 8'd0; end
                    endcase

                    // Check if current pair is sorted
                    if (current > next) begin
                        result <= 1'b0;
                    end

                    // Move to next pair or finish
                    if (index + 4'd1 >= len - 4'd1 || len < 4'd2) begin
                        state <= FINISH;
                    end else begin
                        index <= index + 4'd1;
                    end

                    // Safety: prevent infinite loops
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule