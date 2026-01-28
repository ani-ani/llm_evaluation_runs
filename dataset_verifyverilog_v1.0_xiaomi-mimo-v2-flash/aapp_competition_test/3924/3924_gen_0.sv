module GarbageDisposal(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [9:0] k,
    input wire [9:0] a_in,
    output reg [19:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESS = 2'd1;
    localparam [1:0] FINISH = 2'd2;

    // Internal registers
    reg [1:0] state;
    reg [3:0] day_cnt;        // Current day being processed (0 to n-1)
    reg [9:0] carry;          // Garbage carried to next day (10-bit)
    reg [19:0] bags_total;    // Accumulated bags (20-bit)
    reg [3:0] n_reg;          // Store n locally
    reg [9:0] k_reg;          // Store k locally
    reg [19:0] bags_temp;     // Temporary for bag calculation
    reg [9:0] total_sum;      // a_i + carry (10-bit, max 1023+1023=2046)
    reg [9:0] remainder_temp; // Remainder calculation
    
    // Control signals
    reg is_last_day;
    reg compute_done;
    reg [19:0] next_bags;
    reg [9:0] next_carry;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            day_cnt <= 4'd0;
            carry <= 10'd0;
            bags_total <= 20'd0;
            result <= 20'd0;
            done <= 1'b0;
            n_reg <= 4'd0;
            k_reg <= 10'd0;
            total_sum <= 10'd0;
            bags_temp <= 20'd0;
            remainder_temp <= 10'd0;
            is_last_day <= 1'b0;
            compute_done <= 1'b0;
            next_bags <= 20'd0;
            next_carry <= 10'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        n_reg <= n;
                        k_reg <= k;
                        carry <= 10'd0;
                        bags_total <= 20'd0;
                        day_cnt <= 4'd0;
                        
                        if (n == 4'd0) begin
                            state <= FINISH;
                        end else begin
                            state <= PROCESS;
                        end
                    end
                end

                PROCESS: begin
                    // Pipeline: Calculate total, bags, remainder for current day
                    total_sum <= a_in + carry;
                    is_last_day <= (day_cnt == n_reg - 4'd1);
                    
                    // Calculate total bags needed for this day
                    // If last day: ceil(total / k) = (total + k - 1) / k
                    // If not last day: floor(total / k)
                    if (day_cnt == n_reg - 4'd1) begin
                        if (total_sum == 10'd0) begin
                            bags_temp <= 20'd0;
                            remainder_temp <= 10'd0;
                            compute_done <= 1'b1;
                        end else begin
                            // ceil(total / k) = (total + k - 1) / k
                            if (k_reg == 10'd1) begin
                                bags_temp <= total_sum;
                                remainder_temp <= 10'd0;
                                compute_done <= 1'b1;
                            end else begin
                                bags_temp <= (total_sum + k_reg - 10'd1) / k_reg;
                                remainder_temp <= (total_sum + k_reg - 10'd1) % k_reg;
                                compute_done <= 1'b1;
                            end
                        end
                    end else begin
                        // Not last day: floor(total / k)
                        // Special case: if carry > 0 and total < k, we must take 1 bag
                        // to prevent garbage from being stranded
                        if (total_sum == 10'd0) begin
                            bags_temp <= 20'd0;
                            remainder_temp <= 10'd0;
                            compute_done <= 1'b1;
                        end else if (k_reg == 10'd1) begin
                            bags_temp <= total_sum;
                            remainder_temp <= 10'd0;
                            compute_done <= 1'b1;
                        end else begin
                            if (total_sum < k_reg) begin
                                // Can't fill a bag, but if we have carry, we must take 1 bag
                                if (carry > 10'd0) begin
                                    bags_temp <= 20'd1;
                                    remainder_temp <= total_sum; // Everything goes to carry
                                    compute_done <= 1'b1;
                                end else begin
                                    // No carry, current day only, can leave for next day
                                    bags_temp <= 20'd0;
                                    remainder_temp <= total_sum;
                                    compute_done <= 1'b1;
                                end
                            end else begin
                                bags_temp <= total_sum / k_reg;
                                remainder_temp <= total_sum % k_reg;
                                compute_done <= 1'b1;
                            end
                        end
                    end
                    
                    if (compute_done) begin
                        compute_done <= 1'b0;
                        
                        // Update accumulators
                        bags_total <= bags_total + bags_temp;
                        next_carry <= remainder_temp;
                        next_bags <= bags_temp;
                        
                        day_cnt <= day_cnt + 4'd1;
                        
                        // Check if we're done with all days
                        if (day_cnt + 4'd1 == n_reg) begin
                            // Prepare to handle potential final carry
                            carry <= remainder_temp;
                            if (remainder_temp > 10'd0 && day_cnt + 4'd1 == n_reg) begin
                                // Need one more bag for leftover carry
                                state <= FINISH;
                            end else begin
                                state <= FINISH;
                            end
                        end else begin
                            carry <= remainder_temp;
                        end
                    end
                end

                FINISH: begin
                    // Handle final carry: if carry > 0 after all days, add 1 bag
                    if (carry > 10'd0 && day_cnt == n_reg) begin
                        bags_total <= bags_total + 20'd1;
                        result <= bags_total + 20'd1;
                    end else if (day_cnt == n_reg) begin
                        result <= bags_total;
                    end
                    
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule