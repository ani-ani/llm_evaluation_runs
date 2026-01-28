module min_energy_module(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [7:0] k_in,
    input wire [7:0] a1,
    input wire [7:0] a2,
    input wire [7:0] a3,
    input wire [7:0] a4,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] LOAD = 2'd1;
    localparam [1:0] COMPUTE = 2'd2;
    localparam [1:0] FINISH = 2'd3;

    reg [1:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // DP table for k=1..16
    reg [15:0] dp [0:16];
    integer i, j;

    // Input registers
    reg [3:0] n_reg;
    reg [7:0] k_reg;
    reg [7:0] a_reg [1:4];

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            // Initialize DP table
            for (i = 0; i <= 16; i = i + 1) begin
                dp[i] <= 16'd0;
            end
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= LOAD;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                LOAD: begin
                    // Load inputs
                    n_reg <= n;
                    k_reg <= k_in;
                    a_reg[1] <= a1;
                    a_reg[2] <= a2;
                    a_reg[3] <= a3;
                    a_reg[4] <= a4;
                    next_state <= COMPUTE;
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Compute DP table for k=1..16
                    if (cycle_count == 8'd1) begin
                        // Initialize DP[0]
                        dp[0] <= 16'd0;
                        
                        // Initialize DP[1..4] with a_reg values
                        for (i = 1; i <= 4; i = i + 1) begin
                            if (i <= n_reg) begin
                                dp[i] <= {8'd0, a_reg[i]};
                            end else begin
                                dp[i] <= 16'd0;
                            end
                        end
                        
                        // Initialize DP[5..16] to max value
                        for (i = 5; i <= 16; i = i + 1) begin
                            dp[i] <= 16'hFFFF;
                        end
                    end else if (cycle_count > 8'd1 && cycle_count <= 8'd17) begin
                        // Compute DP[i] for i=2..16
                        i = cycle_count - 8'd1;
                        if (i > 1 && i <= 16) begin
                            dp[i] <= 16'hFFFF;
                            for (j = 1; j < i; j = j + 1) begin
                                if (dp[j] + dp[i - j] < dp[i]) begin
                                    dp[i] <= dp[j] + dp[i - j];
                                end
                            end
                        end
                    end else if (cycle_count == 8'd18) begin
                        // Compute result based on k_reg
                        if (k_reg <= 16) begin
                            result <= dp[k_reg];
                        end else begin
                            // result = DP[16] * (1 << (k_reg - 16))
                            result <= dp[16] << (k_reg - 16);
                        end
                        next_state <= FINISH;
                    end else if (cycle_count >= MAX_CYCLES) begin
                        next_state <= FINISH;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
        end
    end
endmodule