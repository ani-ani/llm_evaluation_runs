module min_rounding_error(
    input clk,
    input rst_n,
    input start,
    input [2:0] n,
    input [31:0] numbers [7:0],
    output reg [31:0] result,
    output reg done
);

    // State encoding
    localparam IDLE = 3'b000;
    localparam COLLECT = 3'b001;
    localparam CALCULATE = 3'b010;
    localparam OPTIMIZE = 3'b011;
    localparam DONE = 3'b100;

    reg [2:0] state;
    reg [2:0] counter; // Iterates up to n (max 4)
    reg [31:0] fractional_sum;
    reg [2:0] fractional_count;
    reg [2:0] integer_count;
    
    // Intermediate registers for calculation
    reg [31:0] opt_k;
    reg [31:0] min_k;
    reg [31:0] max_k;
    reg [31:0] current_diff;
    reg [31:0] best_diff;
    reg [31:0] best_k;

    // Helper logic for multiplication
    // We need to calculate k * 0x00008000 (which is 32768)
    // Also fractional_count * 0x00010000
    wire [63:0] k_mult = {29'b0, opt_k, 15'b0}; // opt_k * 32768
    wire [63:0] fc_mult = {30'b0, fractional_count, 16'b0}; // fractional_count * 65536
    
    // Comparison logic
    reg signed [63:0] diff_calc;
    reg signed [63:0] best_calc;
    
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 0;
            done <= 0;
            counter <= 0;
            fractional_sum <= 0;
            fractional_count <= 0;
            integer_count <= 0;
            opt_k <= 0;
            min_k <= 0;
            max_k <= 0;
            best_diff <= 32'hFFFFFFFF;
            best_k <= 0;
            current_diff <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        state <= COLLECT;
                        counter <= 0;
                        fractional_sum <= 0;
                        fractional_count <= 0;
                        integer_count <= 0;
                    end
                end

                COLLECT: begin
                    // Process 2n numbers (represented as n pairs, iterating n times on pairs)
                    // Here we iterate 2n times actually, or n times if we process pairs. 
                    // Let's iterate 2*n times. But n is max 4, so 8 iterations max.
                    // The problem says n=4 max, 2n=8 numbers.
                    // Let's assume we process 2n items. The input counter iterates 2n times.
                    // Actually, simpler: we iterate 2*n times.
                    // Let's use 'n' as the number of pairs, so total numbers = 2*n.
                    // We'll iterate until counter == (n << 1).
                    
                    if (counter < (n << 1)) begin
                        // Access numbers[counter]
                        // Note: Verilog arrays are usually accessed with indices. 
                        // numbers is defined as [7:0] array of [31:0].
                        if (numbers[counter][15:0] != 16'b0) begin
                            fractional_sum <= fractional_sum + {16'b0, numbers[counter][15:0]};
                            fractional_count <= fractional_count + 1;
                        end else begin
                            integer_count <= integer_count + 1;
                        end
                        counter <= counter + 1;
                    end else begin
                        state <= CALCULATE;
                        counter <= 0;
                    end
                end

                CALCULATE: begin
                    // Compute initial bounds and estimate
                    // min_up = max(0, n - (2n - fractional_count)) = max(0, fractional_count - n)
                    // max_up = min(n, fractional_count)
                    // We need to compute these carefully.
                    
                    if (fractional_count > n) begin
                        min_k <= fractional_count - n;
                    end else begin
                        min_k <= 0;
                    end

                    if (fractional_count > n) begin
                        max_k <= n;
                    end else begin
                        max_k <= fractional_count;
                    end

                    // Optimal estimate: k approx = fractional_sum / 0x00008000
                    // fractional_sum is in Q16.16. Dividing by 0x8000 (scaled 0.5 in Q16.16)
                    // is equivalent to right shifting by 15.
                    opt_k <= fractional_sum >> 15;
                    
                    best_diff <= 32'hFFFFFFFF;
                    
                    state <= OPTIMIZE;
                    counter <= 0;
                end

                OPTIMIZE: begin
                    // We have min_k, max_k. We need to find k in [min_k, max_k]
                    // that minimizes |fractional_sum - k * 0x00008000|.
                    // Since the range is small (max 5 values), we can iterate.
                    // However, a true linear search might take too many cycles if we do 1 per cycle.
                    // But range is small (max n=4, so range size is 5). 
                    // We can unroll or do sequential check.
                    
                    // Let's check one value per cycle.
                    // But wait, the range [min_k, max_k] depends on dynamic values.
                    // We need to generate the values of k to check.
                    // We can't easily loop in hardware without a counter.
                    // Let's use counter to iterate from min_k to max_k.
                    
                    // Problem: min_k and max_k are registers. We can't use them as loop bounds directly
                    // in a synthesizable for-loop inside always_ff.
                    // We will iterate 5 times (max possible) and mask logic if out of bounds.
                    // Or simpler: just check k = round(opt_k), and check neighbors until valid.
                    // But max range is small (5). Let's do a sequential check of candidates.
                    
                    // Optimization: Check 3 candidates: clamp(opt_k), min_k, max_k.
                    // Or iterate 0 to 4 and check if inside range.
                    // Since n <= 4, 2n <= 8. Range is at most 5.
                    
                    // Let's check: k = min_k, min_k+1, ..., max_k.
                    // We need a local counter for this state.
                    // Let's use 'counter' as the iterator k.
                    // Initialize counter to min_k in CALCULATE state.
                    
                    if (counter == 0 && state == OPTIMIZE) begin
                        // Initialize for loop
                        counter <= min_k;
                    end else if (counter <= max_k) begin
                        // Calculate error: |fractional_sum - counter * 0x8000|
                        // counter * 0x8000 = counter << 15
                        // diff = fractional_sum - (counter << 15)
                        // take absolute value
                        
                        if (fractional_sum >= (counter << 15)) begin
                            current_diff <= fractional_sum - (counter << 15);
                        end else begin
                            current_diff <= (counter << 15) - fractional_sum;
                        end
                        
                        // We need to compare in next cycle or use combinational logic.
                        // Let's defer comparison to next cycle to keep timing simple.
                        // We'll update best_diff and best_k in the cycle following the diff calc.
                        // But we are inside one state.
                        
                        // To do this in one state efficiently:
                        // We can have a sub-state or just use the fact that we need 1 cycle to calc diff.
                        // Let's split: One cycle to calc diff, one to compare.
                        // Or calculate diff combinationally.
                        
                        // Combinational calc:
                        reg [31:0] temp_k;
                        reg [31:0] temp_diff;
                        temp_k = counter;
                        if (fractional_sum >= (temp_k << 15)) 
                            temp_diff = fractional_sum - (temp_k << 15);
                        else 
                            temp_diff = (temp_k << 15) - fractional_sum;
                        
                        if (temp_diff < best_diff) begin
                            best_diff <= temp_diff;
                            best_k <= temp_k;
                        end
                        
                        if (counter < max_k) begin
                            counter <= counter + 1;
                        end else begin
                            state <= DONE;
                        end
                    end else begin
                        state <= DONE;
                    end
                end

                DONE: begin
                    result <= best_diff;
                    done <= 1;
                    if (!start) begin
                        state <= IDLE;
                        done <= 0;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule
