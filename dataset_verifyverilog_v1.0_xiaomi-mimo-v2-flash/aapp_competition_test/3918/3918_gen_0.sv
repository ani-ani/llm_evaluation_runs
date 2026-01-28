module MinimizeArrayError (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [7:0] A_in [0:7],
    input wire signed [7:0] B_in [0:7],
    input wire [8:0] K_in,
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] SAMPLE = 3'd1;
    localparam [2:0] COMPUTE_DIFF = 3'd2;
    localparam [2:0] FIND_MAX = 3'd3;
    localparam [2:0] UPDATE_D = 3'd4;
    localparam [2:0] SUM_SQUARES = 3'd5;
    localparam [2:0] FINISH = 3'd6;

    // Internal registers
    reg [2:0] state, next_state;
    reg [8:0] k_counter;          // Counts down from K to 0
    reg [2:0] idx;                // Index for loops and max finding
    reg [2:0] max_idx;            // Index of current maximum
    reg [7:0] d_reg [0:7];        // Storage for differences
    reg [7:0] max_val;            // Current maximum value found
    reg [31:0] temp_sum;          // Accumulator for squares
    reg [15:0] temp_sq;           // Temporary square storage
    reg [2:0] loop_idx;           // General loop index
    reg [1:0] wait_cycle;         // Cycle counter for summing

    // Temporary signals for computation
    wire [15:0] sq_wire [0:7];
    wire [31:0] sum_wire;
    
    // Generate squares for all elements (combinational)
    genvar g;
    generate
        for (g = 0; g < 8; g = g + 1) begin : square_gen
            assign sq_wire[g] = d_reg[g] * d_reg[g]; // 8x8 -> 16-bit
        end
    endgenerate

    // Summation tree (combinational)
    assign sum_wire = (((((sq_wire[0] + sq_wire[1]) + (sq_wire[2] + sq_wire[3])) + 
                        ((sq_wire[4] + sq_wire[5]) + (sq_wire[6] + sq_wire[7]))) << 16) >> 16);

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            k_counter <= 9'd0;
            idx <= 3'd0;
            max_idx <= 3'd0;
            max_val <= 8'd0;
            temp_sum <= 32'd0;
            temp_sq <= 16'd0;
            loop_idx <= 3'd0;
            wait_cycle <= 2'd0;
            // Initialize d_reg array
            d_reg[0] <= 8'd0;
            d_reg[1] <= 8'd0;
            d_reg[2] <= 8'd0;
            d_reg[3] <= 8'd0;
            d_reg[4] <= 8'd0;
            d_reg[5] <= 8'd0;
            d_reg[6] <= 8'd0;
            d_reg[7] <= 8'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    k_counter <= 9'd0;
                    idx <= 3'd0;
                    wait_cycle <= 2'd0;
                    if (start) begin
                        k_counter <= K_in;
                    end
                end
                
                SAMPLE: begin
                    // Sample input data and convert to absolute differences
                    // Input range -256 to 255 maps to 0-255 for unsigned differences
                    // d = |A - B|, truncated to 8 bits
                    d_reg[0] <= (A_in[0] > B_in[0]) ? (A_in[0] - B_in[0]) : (B_in[0] - A_in[0]);
                    d_reg[1] <= (A_in[1] > B_in[1]) ? (A_in[1] - B_in[1]) : (B_in[1] - A_in[1]);
                    d_reg[2] <= (A_in[2] > B_in[2]) ? (A_in[2] - B_in[2]) : (B_in[2] - A_in[2]);
                    d_reg[3] <= (A_in[3] > B_in[3]) ? (A_in[3] - B_in[3]) : (B_in[3] - A_in[3]);
                    d_reg[4] <= (A_in[4] > B_in[4]) ? (A_in[4] - B_in[4]) : (B_in[4] - A_in[4]);
                    d_reg[5] <= (A_in[5] > B_in[5]) ? (A_in[5] - B_in[5]) : (B_in[5] - A_in[5]);
                    d_reg[6] <= (A_in[6] > B_in[6]) ? (A_in[6] - B_in[6]) : (B_in[6] - A_in[6]);
                    d_reg[7] <= (A_in[7] > B_in[7]) ? (A_in[7] - B_in[7]) : (B_in[7] - A_in[7]);
                    idx <= 3'd0;
                end
                
                COMPUTE_DIFF: begin
                    // Ready for operation loop
                    // No register updates here
                end
                
                FIND_MAX: begin
                    // Find index with maximum d value using cascaded comparison
                    // Start with idx=0 as initial max
                    if (idx == 3'd0) begin
                        max_idx <= 3'd0;
                        max_val <= d_reg[0];
                    end else begin
                        // Compare current d[idx] with max_val
                        if (d_reg[idx] > max_val) begin
                            max_idx <= idx;
                            max_val <= d_reg[idx];
                        end
                    end
                    idx <= idx + 3'd1;
                end
                
                UPDATE_D: begin
                    // Update the maximum element
                    if (max_val > 8'd0) begin
                        d_reg[max_idx] <= max_val - 8'd1;
                    end else begin
                        // If max is 0, we must use the operation
                        // Set to 1 (increases error temporarily)
                        d_reg[max_idx] <= 8'd1;
                    end
                    k_counter <= k_counter - 9'd1;
                    idx <= 3'd0; // Reset for next iteration or sum
                end
                
                SUM_SQUARES: begin
                    // Compute sum of squares
                    // Two-cycle wait for combinational logic to settle
                    wait_cycle <= wait_cycle + 2'd1;
                    if (wait_cycle == 2'd1) begin
                        result <= sum_wire;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = SAMPLE;
                else next_state = IDLE;
            end
            
            SAMPLE: begin
                next_state = COMPUTE_DIFF;
            end
            
            COMPUTE_DIFF: begin
                if (k_counter > 9'd0) begin
                    next_state = FIND_MAX;
                end else begin
                    next_state = SUM_SQUARES;
                end
            end
            
            FIND_MAX: begin
                if (idx >= 3'd7) begin
                    next_state = UPDATE_D;
                end else begin
                    next_state = FIND_MAX;
                end
            end
            
            UPDATE_D: begin
                next_state = COMPUTE_DIFF;
            end
            
            SUM_SQUARES: begin
                if (wait_cycle >= 2'd1) begin
                    next_state = FINISH;
                end else begin
                    next_state = SUM_SQUARES;
                end
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

endmodule