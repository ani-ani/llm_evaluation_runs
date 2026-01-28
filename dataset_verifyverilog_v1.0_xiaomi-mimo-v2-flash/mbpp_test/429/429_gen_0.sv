module elementwise_and_t8 (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr1 [0:7],
    input wire [7:0] arr2 [0:7],
    input wire [3:0] len,
    output reg [7:0] result [0:7],
    output reg done
);

    // State definitions
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] COMPUTE   = 3'd1;
    localparam [2:0] DONE      = 3'd2;
    localparam [2:0] WAIT      = 3'd3; // Wait for start to go low

    reg [2:0] state;
    reg [3:0] idx; // Current index for iteration (0-7)
    reg start_d;   // Delayed start signal to detect rising edge
    
    // Synthesizable array index storage
    reg [7:0] arr1_reg [0:7];
    reg [7:0] arr2_reg [0:7];
    reg [3:0] len_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            done <= 1'b0;
            idx <= 4'd0;
            start_d <= 1'b0;
            len_reg <= 4'd0;
            // Initialize result array to zeros
            result[0] <= 8'd0;
            result[1] <= 8'd0;
            result[2] <= 8'd0;
            result[3] <= 8'd0;
            result[4] <= 8'd0;
            result[5] <= 8'd0;
            result[6] <= 8'd0;
            result[7] <= 8'd0;
            // Initialize input regs
            arr1_reg[0] <= 8'd0;
            arr1_reg[1] <= 8'd0;
            arr1_reg[2] <= 8'd0;
            arr1_reg[3] <= 8'd0;
            arr1_reg[4] <= 8'd0;
            arr1_reg[5] <= 8'd0;
            arr1_reg[6] <= 8'd0;
            arr1_reg[7] <= 8'd0;
            arr2_reg[0] <= 8'd0;
            arr2_reg[1] <= 8'd0;
            arr2_reg[2] <= 8'd0;
            arr2_reg[3] <= 8'd0;
            arr2_reg[4] <= 8'd0;
            arr2_reg[5] <= 8'd0;
            arr2_reg[6] <= 8'd0;
            arr2_reg[7] <= 8'd0;
        end else begin
            // Default assignments
            done <= 1'b0;
            start_d <= start;
            
            case (state)
                IDLE: begin
                    if (start && !start_d) begin
                        // Capture inputs at start
                        len_reg <= len;
                        arr1_reg[0] <= arr1[0];
                        arr1_reg[1] <= arr1[1];
                        arr1_reg[2] <= arr1[2];
                        arr1_reg[3] <= arr1[3];
                        arr1_reg[4] <= arr1[4];
                        arr1_reg[5] <= arr1[5];
                        arr1_reg[6] <= arr1[6];
                        arr1_reg[7] <= arr1[7];
                        arr2_reg[0] <= arr2[0];
                        arr2_reg[1] <= arr2[1];
                        arr2_reg[2] <= arr2[2];
                        arr2_reg[3] <= arr2[3];
                        arr2_reg[4] <= arr2[4];
                        arr2_reg[5] <= arr2[5];
                        arr2_reg[6] <= arr2[6];
                        arr2_reg[7] <= arr2[7];
                        idx <= 4'd0;
                        state <= COMPUTE;
                    end
                end

                COMPUTE: begin
                    // Perform elementwise AND based on current index
                    if (idx < len_reg) begin
                        // Inside valid range: AND operation
                        result[idx] <= arr1_reg[idx] & arr2_reg[idx];
                    end else begin
                        // Outside valid range: zero out
                        result[idx] <= 8'd0;
                    end
                    
                    if (idx == 4'd7) begin
                        // Last index processed
                        state <= DONE;
                    end else begin
                        idx <= idx + 4'd1;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    state <= WAIT;
                end

                WAIT: begin
                    // Wait for start to go low before returning to IDLE
                    if (!start) begin
                        state <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule