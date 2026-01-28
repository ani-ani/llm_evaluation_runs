module ToyTrainSolver (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n_in,
    input wire [3:0] candy_count [0:15],
    input wire [3:0] min_dist [0:15],
    output reg [15:0] result [0:15],
    output reg done
);

    // State declarations
    localparam [2:0] IDLE     = 3'd0;
    localparam [2:0] LOAD     = 3'd1;
    localparam [2:0] CALCULATE = 3'd2;
    localparam [2:0] OUTPUT   = 3'd3;
    localparam [2:0] FINISH   = 3'd4;

    // Internal registers
    reg [2:0] state;
    reg [3:0] i, j; // i for station s, j for station i
    reg [15:0] max_time [0:15]; // Max time per starting station
    reg [15:0] dist_val;
    reg [15:0] time_val;
    reg [3:0] n_reg;
    reg [3:0] candy_reg [0:15];
    reg [3:0] m_dist_reg [0:15];
    reg [15:0] result_reg [0:15];

    // Combinational logic for distance calculation: dist(s, i)
    wire [15:0] dist_wire;
    wire [15:0] i_minus_s;
    wire [15:0] i_plus_n_minus_s;
    
    assign i_minus_s = (j >= i) ? ({12'd0, j} - {12'd0, i}) : (16'd0); // Simplified logic handled in sequential
    
    // Intermediate values for time calculation
    wire [15:0] candy_mult; // n * (candy - 1)
    wire [15:0] term1;      // dist(s, i)
    wire [15:0] term2;      // n * (candy_count[i] - 1)
    wire [15:0] term3;      // min_dist[i]
    wire [15:0] total_time;

    // Helper for dist calculation in block
    reg [15:0] dist_reg;

    always @(posedge clk) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            for (int k = 0; k < 16; k = k + 1) begin
                max_time[k] <= 16'd0;
                result_reg[k] <= 16'd0;
                candy_reg[k] <= 4'd0;
                m_dist_reg[k] <= 4'd0;
            end
            n_reg <= 4'd0;
            i <= 4'd0;
            j <= 4'd0;
            dist_reg <= 16'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= LOAD;
                        n_reg <= n_in;
                    end
                end

                LOAD: begin
                    // Load input arrays into internal regs
                    // We can load in parallel or sequentially. Sequential is simpler.
                    // Using a counter logic here to load all 16 elements
                    if (j < 16) begin
                        candy_reg[j] <= candy_count[j];
                        m_dist_reg[j] <= min_dist[j];
                        j <= j + 4'd1;
                    end else begin
                        j <= 4'd0; // Reset j for calculation phase
                        state <= CALCULATE;
                        // Initialize max_time for all s to 0 (or smallest possible)
                        // Actually, we iterate s and i. Let's reset max_time here.
                        for (int k = 0; k < 16; k = k + 1) begin
                            max_time[k] <= 16'd0;
                        end
                    end
                end

                CALCULATE: begin
                    // Loop structure:
                    // For s from 0 to n-1
                    //   For i from 0 to n-1
                    //     if (candy_count[i] > 0)
                    //       time = dist(s, i) + n*(candy-1) + min_dist[i]
                    //       max_time[s] = max(max_time[s], time)
                    // To save latency, we can do this in nested loops or fully parallel.
                    // Given constraints (10-20 cycles), we can iterate.
                    // Cycle count: n * n = 256 max. That's too slow if done naively.
                    // Optimization: Parallelize over 's' (start stations).
                    // We calculate time(s, i) for all s in parallel for a fixed i.
                    
                    // Let's implement a sequential loop over i (station with candy)
                    // And compute for all s (start station) in parallel logic.
                    // This takes n cycles.
                    
                    if (i < 16) begin
                        // Only process if this station has candies
                        if (candy_reg[i] > 4'd0) begin
                            // Calculate terms for this 'i'
                            // term1 (dist): calculated per 's' in a sub-cycle or combinational logic
                            // term2: n_reg * (candy_reg[i] - 1)
                            // term3: m_dist_reg[i]
                            
                            // We will compute max_time[s] update in combinational logic below
                            // and latch it here.
                            // However, combinational logic for 16 s * 16 i is heavy but manageable.
                            // Let's do it inside the always block to be explicit.
                            
                            for (int s = 0; s < 16; s = s + 1) begin
                                if (s < n_reg) begin
                                    // dist(s, i)
                                    if (i >= s)
                                        dist_val = {12'd0, i} - {12'd0, s};
                                    else
                                        dist_val = {12'd0, i} + {12'd0, n_reg} - {12'd0, s};
                                    
                                    time_val = dist_val + ({12'd0, n_reg} * ({4'd0, candy_reg[i]} - 16'd1)) + {12'd0, m_dist_reg[i]};
                                    
                                    if (time_val > max_time[s]) begin
                                        max_time[s] <= time_val;
                                    end
                                end
                            end
                        end
                        i <= i + 4'd1;
                    end else begin
                        // Done with all i
                        i <= 4'd0;
                        state <= OUTPUT;
                    end
                end

                OUTPUT: begin
                    // Transfer max_time to result_reg
                    for (int k = 0; k < 16; k = k + 1) begin
                        if (k < n_reg)
                            result_reg[k] <= max_time[k];
                        else
                            result_reg[k] <= 16'd0;
                    end
                    state <= FINISH;
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

    // Output assignment
    always @(*) begin
        result = result_reg;
    end

endmodule