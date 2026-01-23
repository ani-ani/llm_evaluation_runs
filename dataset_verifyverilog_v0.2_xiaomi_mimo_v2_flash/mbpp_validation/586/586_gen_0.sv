module array_rotator (
    input clk,
    input rst_n,
    input start,
    input [2:0] n,
    input [7:0] arr [0:7],
    output reg [7:0] result [0:7],
    output reg done
);

    // State encoding
    localparam IDLE = 1'b0;
    localparam PROCESSING = 1'b1;
    reg state;
    
    // Combinational logic for rotation
    // This logic calculates the rotated index for each output element
    // In PROCESSING state, result[i] = arr[(i + n) % 8]
    // Since 8 is a power of 2, modulo 8 is equivalent to taking the lower 3 bits
    wire [7:0] next_result [0:7];
    
    genvar i;
    generate
        for (i = 0; i < 8; i = i + 1) begin : gen_rot_logic
            // Calculate source index: (i + n) mod 8
            // Since indices are 0-7 and n is 0-7, (i + n) ranges 0-14
            // Taking lower 3 bits gives (i + n) % 8
            wire [3:0] src_idx = i[3:0] + n[3:0]; // 4-bit addition to handle overflow
            assign next_result[i] = arr[src_idx[2:0]];
        end
    endgenerate
    
    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            // Reset result array
            for (int j = 0; j < 8; j = j + 1) begin
                result[j] <= 8'h00;
            end
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= PROCESSING;
                        // Compute result immediately in same cycle
                        for (int j = 0; j < 8; j = j + 1) begin
                            result[j] <= next_result[j];
                        end
                        done <= 1'b1;
                    end else begin
                        done <= 1'b0;
                    end
                end
                
                PROCESSING: begin
                    // In this state, done is already high and result is valid
                    // Stay in this state until start goes low to avoid re-triggering
                    if (!start) begin
                        state <= IDLE;
                        done <= 1'b0;
                    end
                end
                
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule