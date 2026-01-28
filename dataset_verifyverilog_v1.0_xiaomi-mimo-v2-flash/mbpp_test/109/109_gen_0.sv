module parity_rotator (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] s,
    input wire [7:0] n,
    output reg [4:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE      = 2'd0;
    localparam [1:0] ROTATING  = 2'd1;
    localparam [1:0] COUNTING  = 2'd2;
    localparam [1:0] FINISHING = 2'd3;

    // Internal registers
    reg [1:0] state;
    reg [7:0] reg_string;      // 8-bit register to store and rotate string
    reg [7:0] rotation_counter; // Counts rotations performed
    reg [7:0] rotation_target;  // Store target n
    reg [2:0] bit_index;       // For counting bits
    reg [4:0] count_reg;       // Accumulated count
    reg start_hold;            // Hold start signal

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            reg_string <= 8'd0;
            rotation_counter <= 8'd0;
            rotation_target <= 8'd0;
            bit_index <= 3'd0;
            count_reg <= 5'd0;
            result <= 5'd0;
            done <= 1'b0;
            start_hold <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 5'd0;
                    start_hold <= 1'b0;
                    if (start) begin
                        reg_string <= s;
                        rotation_target <= n;
                        rotation_counter <= 8'd0;
                        if (n == 8'd0) begin
                            // No rotation needed, go directly to counting
                            state <= COUNTING;
                        end else begin
                            state <= ROTATING;
                        end
                    end
                end

                ROTATING: begin
                    // Left rotation: shift left, wrap MSB to LSB
                    reg_string <= {reg_string[6:0], reg_string[7]};
                    rotation_counter <= rotation_counter + 8'd1;
                    
                    // Check if done rotating
                    if (rotation_counter + 8'd1 >= rotation_target) begin
                        state <= COUNTING;
                    end else if (rotation_counter >= 8'd255) begin
                        // Safety: prevent infinite loop
                        state <= COUNTING;
                    end
                end

                COUNTING: begin
                    // Initialize counting state
                    bit_index <= 3'd0;
                    count_reg <= 5'd0;
                    state <= FINISHING;
                end

                FINISHING: begin
                    if (bit_index <= 3'd7) begin
                        // Count each bit
                        if (reg_string[bit_index]) begin
                            count_reg <= count_reg + 5'd1;
                        end
                        bit_index <= bit_index + 3'd1;
                    end else begin
                        // Counting complete
                        result <= count_reg;
                        done <= 1'b1;
                        state <= IDLE;
                    end
                end

                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                    result <= 5'd0;
                end
            endcase
        end
    end

endmodule