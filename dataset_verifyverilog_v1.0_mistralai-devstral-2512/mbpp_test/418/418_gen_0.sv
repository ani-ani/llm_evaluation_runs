module MaxLengthFinder(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] lengths [0:3],
    output reg [1:0] max_index,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] COMPARE = 3'd1;
    localparam [2:0] FINISH  = 3'd2;

    reg [2:0] state;
    reg [1:0] current_index;
    reg [3:0] max_len;
    reg [3:0] cycle_count;
    localparam [3:0] MAX_CYCLES = 4'd10;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_index <= 2'd0;
            max_len <= 4'd0;
            max_index <= 2'd0;
            done <= 1'b0;
            cycle_count <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 4'd0;
                    if (start) begin
                        state <= COMPARE;
                        current_index <= 2'd0;
                        max_len <= 4'd0;
                        max_index <= 2'd0;
                    end
                end

                COMPARE: begin
                    cycle_count <= cycle_count + 4'd1;

                    // Compare current length with max_len
                    if (lengths[current_index] > max_len) begin
                        max_len <= lengths[current_index];
                        max_index <= current_index;
                    end

                    // Move to next index
                    if (current_index == 2'd3) begin
                        state <= FINISH;
                    end else begin
                        current_index <= current_index + 2'd1;
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