module LongestSublistFinder(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr [0:7],
    input wire [7:0] valid,
    input wire [3:0] lengths [0:7],
    output reg [3:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] COMPLETE = 2'd2;

    reg [1:0] state;
    reg [3:0] current_max;
    reg [2:0] index;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd20;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 4'd0;
            done <= 1'b0;
            current_max <= 4'd0;
            index <= 3'd0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE;
                        current_max <= 4'd0;
                        index <= 3'd0;
                    end
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;

                    // Check if current sublist is valid
                    if (valid[index]) begin
                        // Compare current sublist length with current_max
                        if (lengths[index] > current_max) begin
                            current_max <= lengths[index];
                        end
                    end

                    // Move to next index
                    index <= index + 3'd1;

                    // Check if we've processed all sublists or reached max cycles
                    if ((index == 3'd8) || (cycle_count >= MAX_CYCLES)) begin
                        state <= COMPLETE;
                        result <= current_max;
                    end
                end

                COMPLETE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule