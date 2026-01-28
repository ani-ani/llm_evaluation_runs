module xor_pair_sum(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr [0:15],
    input wire [3:0] len,
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH  = 2'd2;

    // State and counter registers
    reg [1:0] state;
    reg [3:0] i_counter;
    reg [3:0] j_counter;
    reg [31:0] accumulator;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            i_counter <= 4'd0;
            j_counter <= 4'd0;
            accumulator <= 32'd0;
            result <= 32'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        // Check if array length is 0 or 1
                        if (len <= 4'd1) begin
                            state <= FINISH;
                        end else begin
                            state <= COMPUTE;
                            i_counter <= 4'd0;
                            j_counter <= 4'd1;
                            accumulator <= 32'd0;
                        end
                    end
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;

                    // Compute XOR for current pair
                    reg [7:0] xor_result;
                    xor_result = arr[i_counter] ^ arr[j_counter];

                    // Accumulate the result
                    accumulator <= accumulator + 32'd0 + xor_result;

                    // Move to next pair
                    if (j_counter == len - 4'd1) begin
                        // Move to next i
                        i_counter <= i_counter + 4'd1;
                        j_counter <= i_counter + 4'd1;
                    end else begin
                        j_counter <= j_counter + 4'd1;
                    end

                    // Check if all pairs processed
                    if (i_counter == len - 4'd2 && j_counter == len - 4'd1) begin
                        state <= FINISH;
                    end else if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    result <= accumulator;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule