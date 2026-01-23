module curfew_enforcement(
    input clk,
    input rst_n,
    input start,
    input [7:0] d_in,
    input valid_in,
    input [31:0] a_in,
    output reg [5:0] addr_out,
    output reg [15:0] result,
    output reg done,
    output reg req_en
);

    // Parameters
    parameter N = 64;
    parameter MAX_D = 32;
    parameter B = 16;

    // State Encoding
    localparam IDLE = 3'b001;
    localparam LOAD = 3'b010;
    localparam COMPUTE = 3'b100;
    // DONE state is implied by done signal, but we use a separate state for clarity or reset logic
    localparam DONE = 3'b111; // Using a distinct state

    // Registers
    reg [2:0] state;
    reg [7:0] d_reg;
    reg [31:0] prefix_sum [0:N-1]; // BRAM implementation logic handled by synthesis tool
    reg [31:0] total_sum;
    reg [31:0] a_in_buf;
    
    // Loop Variables
    reg [5:0] load_cnt;
    reg [5:0] i; // loop counter for compute (1 to N/2)
    
    // Intermediate Calculation Registers
    reg [31:0] left_limit;
    reg [31:0] right_limit;
    reg [31:0] left_students;
    reg [31:0] right_students;
    reg [31:0] max_fill;
    reg [31:0] complaints;
    reg [31:0] max_complaints;
    
    // Combinational helper signals for compute state
    wire [31:0] left_idx;
    wire [31:0] right_idx;
    wire [31:0] next_complaints;
    
    // Division helper logic (iterative subtraction)
    reg [31:0] div_op;
    reg [31:0] div_result;
    reg [31:0] div_remainder;
    reg div_start;
    reg div_done;
    wire div_busy;

    // Assignment for address output
    always @(*) begin
        addr_out = load_cnt;
    end

    // State Transition and Datapath Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            req_en <= 1'b0;
            done <= 1'b0;
            result <= 16'b0;
            load_cnt <= 6'b0;
            total_sum <= 32'b0;
            i <= 6'b0;
            max_complaints <= 32'b0;
            div_start <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    req_en <= 1'b0;
                    load_cnt <= 6'b0;
                    total_sum <= 32'b0;
                    i <= 6'b1; // Start loop at 1
                    max_complaints <= 32'b0;
                    
                    if (start) begin
                        state <= LOAD;
                        req_en <= 1'b1;
                    end
                end

                LOAD: begin
                    if (valid_in) begin
                        prefix_sum[load_cnt] <= (load_cnt == 0) ? a_in : (prefix_sum[load_cnt - 1] + a_in);
                        total_sum <= total_sum + a_in;
                        load_cnt <= load_cnt + 1;
                        
                        if (load_cnt == N - 1) begin
                            state <= COMPUTE;
                            req_en <= 1'b0;
                            // Initialize compute variables
                            d_reg <= d_in;
                        end else begin
                            // Request next address
                            // load_cnt is updated, so addr_out updates combinationally
                        end
                    end
                end

                COMPUTE: begin
                    if (i <= N/2) begin
                        // Only perform logic if we are not waiting for division
                        if (!div_busy && !div_done && !div_start) begin
                            // Calculate Limits
                            // left_limit = i * d_reg
                            // right_limit = N - 1 - i * d_reg
                            // Note: N is parameter, assumed 64. N-1 = 63.
                            // We need to be careful with indices bounds.
                            
                            // Since multiplication is not combinational in this context (to avoid huge logic depth),
                            // we can assume d_reg is small or use i counter multiplication logic here.
                            // Actually, let's compute these on the fly with accumulators if needed, but for simplicity:
                            // i*d. i increases by 1 each cycle. So we can accumulate d_reg.
                            // However, requirements say bounded iteration. Let's do calculation.
                            
                            // Using i*d logic:
                            // In a real ASIC, we'd use a pipelined multiplier or MAC.
                            // Here we assume a combinational multiplier is okay for small sizes (8x6 bit).
                            
                            // Check bounds for indices
                            // left_limit_index = (i * d_reg);
                            // right_limit_index = (N - 1) - (i * d_reg);
                            
                            if (i * d_reg < N) begin
                                left_students <= prefix_sum[i * d_reg];
                            end else begin
                                left_students <= total_sum;
                            end
                            
                            if ((N - 1) >= (i * d_reg)) begin
                                right_students <= total_sum - prefix_sum[(N - 1) - (i * d_reg)];
                            end else begin
                                right_students <= 0;
                            end
                            
                            // Start division in next cycle or combinational path?
                            // To avoid combinational loops, we use a state flag.
                            max_fill <= (prefix_sum[i * d_reg] < (total_sum - prefix_sum[(N - 1) - (i * d_reg)])) ? 
                                        prefix_sum[i * d_reg] : (total_sum - prefix_sum[(N - 1) - (i * d_reg)]);
                            
                            div_start <= 1'b1;
                            // Set divisor B
                            div_op <= 32'd16; // B is 16
                        end else if (div_done) begin
                            div_start <= 1'b0;
                            
                            // complaints = i - (max_fill / B)
                            // div_result holds max_fill / B
                            // complaints = i - div_result
                            
                            if (i < div_result) begin // Should not happen if inputs are correct, but clamp to 0
                                complaints <= 0;
                            end else begin
                                complaints <= i - div_result;
                            end
                            
                            // Update max complaints
                            // We need to wait one cycle for complaints to stabilize if logic is pipelined,
                            // but here we are updating registers in the same cycle div_result is valid.
                            // Actually, we need to compare newly calculated complaints with stored max.
                            
                            if (i == 1) begin
                                max_complaints <= i - div_result;
                            end else begin
                                if (i - div_result > max_complaints) begin
                                    max_complaints <= i - div_result;
                                end
                            end
                            
                            // Increment loop counter
                            i <= i + 1;
                        end else begin
                            div_start <= 1'b0; // Ensure we don't trigger multiple starts
                        end
                    end else begin
                        // Loop finished
                        result <= max_complaints[15:0]; // Truncate to 16-bit as per output spec
                        state <= DONE;
                        done <= 1'b1;
                    end
                end

                DONE: begin
                    // Wait for reset or start
                    if (start) begin
                        // Restart logic handled in IDLE transition, but need to reset done
                        done <= 1'b0;
                        state <= IDLE; // Transition back to IDLE to handle start properly
                    end
                end
            endcase
        end
    end
    
    // Division Logic Unit (Iterative Subtraction for B=16)
    // Since B is 16 (power of 2), we could use shift. But requirement says "or subtraction loop".
    // Let's implement a simple iterative counter.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            div_done <= 1'b0;
            div_result <= 32'b0;
            div_remainder <= 32'b0;
        end else begin
            if (div_start) begin
                // Initialize division
                div_result <= 32'b0;
                div_remainder <= max_fill; // The number to divide
                div_done <= 1'b0;
            end else if (div_remainder >= B && !div_done) begin
                // Subtract B repeatedly (this is slow for large numbers, but bounded by N/B)
                // Since N is small, we can do this in a few cycles or single cycle if we use shift.
                // The instruction says "unroll or iterate". Let's do it in one cycle using shift if B=16.
                // B=16 is 2^4. So result = value >> 4.
                
                // Optimization: Since B is constant 16, we use shift.
                div_result <= max_fill >> 4;
                div_remainder <= 0;
                div_done <= 1'b1;
            end else if (!div_start && !div_done) begin
                // If input is 0 or small
                div_result <= 0;
                div_done <= 1'b1;
            end else if (div_done) begin
                div_done <= 1'b0; // Pulse done for one cycle
            end
        end
    end
    
    assign div_busy = div_start || (!div_done && (div_remainder >= B) && !div_done); // Simple busy signal

endmodule