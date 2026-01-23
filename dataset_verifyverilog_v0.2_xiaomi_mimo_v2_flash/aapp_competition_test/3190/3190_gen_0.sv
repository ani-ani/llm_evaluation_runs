module voodoo_average (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] valid_length,
    input wire [31:0] price_i,
    input wire [31:0] P,
    output reg [31:0] result,
    output reg done,
    output reg input_ready
);

    // Parameters
    parameter N = 16;
    parameter IDX_WIDTH = 4; // ceil(log2(16))

    // States
    localparam IDLE = 3'b001;
    localparam LOAD_PRICES = 3'b010;
    localparam COMPUTE = 3'b100;

    // State register
    reg [2:0] state;
    reg [2:0] next_state;

    // Internal registers
    reg [31:0] prices [0:15];
    reg [3:0] load_cnt;
    reg [3:0] i_reg; // Outer loop index
    reg [3:0] j_reg; // Inner loop index
    reg [63:0] running_sum; // Accumulated sum for current i
    reg [31:0] result_reg;
    reg done_reg;
    reg input_ready_reg;

    // Combinational helper signals
    wire [63:0] threshold;
    wire [63:0] next_sum;
    wire sum_ge_threshold;

    // Calculations
    assign threshold = {32'b0, P} * (j_reg - i_reg + 1);
    assign next_sum = running_sum + {32'b0, prices[j_reg]};
    assign sum_ge_threshold = (next_sum >= threshold);

    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = LOAD_PRICES;
                else
                    next_state = IDLE;
            end
            LOAD_PRICES: begin
                if (load_cnt == valid_length) // Loaded all inputs
                    next_state = COMPUTE;
                else
                    next_state = LOAD_PRICES;
            end
            COMPUTE: begin
                // Termination condition: i reaches valid_length
                if (i_reg >= valid_length)
                    next_state = DONE;
                else
                    next_state = COMPUTE;
            end
            DONE: begin
                // Stay in DONE until next start
                if (start)
                    next_state = LOAD_PRICES;
                else
                    next_state = DONE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic for state and outputs
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'b0;
            done <= 1'b0;
            input_ready <= 1'b0;
            load_cnt <= 4'd0;
            i_reg <= 4'd0;
            j_reg <= 4'd0;
            running_sum <= 64'b0;
            // Initialize prices array (optional but good practice for simulation)
            // Synthesis tools usually infer RAM/FFs without explicit init unless needed
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    if (start) begin
                        // Prepare for loading
                        load_cnt <= 4'd0;
                        input_ready <= 1'b1;
                        done <= 1'b0;
                        result <= 32'b0;
                    end
                end

                LOAD_PRICES: begin
                    if (input_ready && (load_cnt < valid_length)) begin
                        prices[load_cnt] <= price_i;
                        load_cnt <= load_cnt + 1;
                    end
                    if (load_cnt + 1 == valid_length) begin
                        // Last input being accepted this cycle
                        input_ready <= 1'b0;
                    end
                end

                COMPUTE: begin
                    // Logic to iterate i and j
                    // Strategy: maintain running_sum for current i. 
                    // When j increments, add new price. 
                    // When j reaches end, reset sum and increment i.
                    
                    if (i_reg < valid_length) begin
                        if (j_reg < valid_length) begin
                            // We are calculating for pair (i_reg, j_reg)
                            // Compare sum of prices[i..j] with P * (j-i+1)
                            
                            // Note: running_sum holds sum of prices[i..j-1] initially.
                            // In the first iteration for a fixed i, j==i, so running_sum is 0.
                            // We add prices[j].
                            
                            if (sum_ge_threshold) begin
                                result <= result + 1;
                            end
                            
                            // Update running sum for next j
                            running_sum <= next_sum;
                            
                            // Increment j
                            j_reg <= j_reg + 1;
                        end else begin
                            // j reached valid_length (end of inner loop)
                            // Reset j, increment i, reset running sum
                            j_reg <= i_reg + 1; // Start j for next i
                            i_reg <= i_reg + 1;
                            running_sum <= 64'b0;
                        end
                    end
                end

                DONE: begin
                    // Result is already stored in 'result' register
                    // 'done' signal is handled below
                    // Keep 'result' stable
                end
            endcase

            // Handle start signal overriding state transitions or specific edge cases
            // Specifically, if in IDLE and start comes, state goes to LOAD, handled by next_state logic.
            // However, the register updates inside IDLE block handle the initial setup.
        end
    end

    // Done signal logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
        end else begin
            if (state == COMPUTE && next_state == DONE) begin
                done <= 1'b1;
            end else if (start) begin
                done <= 1'b0; // Reset done when new computation starts
            end
        end
    end

endmodule
