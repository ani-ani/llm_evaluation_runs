module wool_sequence_counter (
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [3:0] m,
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] DONE    = 2'd2;

    // Constants
    localparam [31:0] MOD = 32'd1000000009;

    // Internal registers
    reg [1:0] state;
    reg [3:0] i;                // Loop counter (1 to n)
    reg [31:0] product;         // Accumulated product
    reg [31:0] pow2m;           // 2^m
    reg [31:0] factor;          // Current factor (pow2m - i or adjusted)
    reg [63:0] temp_mult;       // Intermediate for multiplication
    reg [7:0] cycle_count;      // Safety counter
    localparam [7:0] MAX_CYCLES = 8'd50;

    // Combinational logic for factor calculation
    wire [31:0] diff;
    wire [31:0] adjusted_factor;
    
    assign diff = pow2m - {28'd0, i};
    assign adjusted_factor = diff[31] ? (MOD - ({28'd0, i} - pow2m)) : diff;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialize all registers
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            i <= 4'd0;
            product <= 32'd1;
            pow2m <= 32'd0;
            factor <= 32'd0;
            temp_mult <= 64'd0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        // Compute pow2m = 2^m
                        pow2m <= 32'd1 << m;
                        // Initialize loop
                        i <= 4'd1;
                        product <= 32'd1;
                        state <= COMPUTE;
                    end
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Calculate factor for this iteration
                    if (pow2m >= {28'd0, i}) begin
                        factor <= pow2m - {28'd0, i};
                    end else begin
                        factor <= MOD - ({28'd0, i} - pow2m);
                    end
                    
                    // Compute product * factor
                    temp_mult <= product * factor;
                    
                    // Check if loop is complete or safety timeout
                    if (i >= n || cycle_count >= MAX_CYCLES) begin
                        if (cycle_count < MAX_CYCLES) begin
                            // Update final product before moving to DONE
                            product <= temp_mult % MOD;
                        end
                        state <= DONE;
                    end else begin
                        // Update product and increment i
                        product <= temp_mult % MOD;
                        i <= i + 4'd1;
                    end
                end

                DONE: begin
                    result <= product;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule