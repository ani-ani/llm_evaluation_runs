module pokemon_go_cost (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] N,
    input wire [9:0] P_scaled,
    output reg [63:0] cost,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;
    
    // Internal registers
    reg [31:0] step;
    reg [63:0] total_cost;
    reg [31:0] prob [0:100];
    reg [31:0] prob_next [0:100];
    reg [31:0] q_power [0:100];
    reg [31:0] C [0:100];
    reg [31:0] T [0:100][0:100];
    
    // Convert P_scaled to fixed-point
    reg [31:0] P_fixed;
    reg [31:0] q_fixed;
    
    integer i, j, k;

    // Convert scaled P to fixed-point
    always @(*) begin
        P_fixed = P_scaled * (1 << 16);
        q_fixed = (1 << 32) - P_fixed;
        
        // Precompute q_power
        q_power[0] = 1 << 32;
        for (i = 1; i < 101; i = i + 1) begin
            q_power[i] = (q_power[i-1] * q_fixed) >> 32;
        end
        
        // Precompute C
        for (i = 0; i < 101; i = i + 1) begin
            if (i == 0) begin
                C[i] = 5 << 32;
            end else begin
                C[i] = (5 << 32) * q_power[i] >> 32;
            end
        end
        
        // Precompute T
        for (i = 0; i < 101; i = i + 1) begin
            for (j = 0; j < 101; j = j + 1) begin
                T[i][j] = 0;
            end
            if (i == 0) begin
                T[0][100] = 1 << 32;
            end else begin
                // transitions to states i-1 down to 1
                for (k = 1; k < i; k = k + 1) begin
                    T[i][i - k] = (P_fixed * q_power[k-1]) >> 32;
                end
                // catch on last ball
                T[i][0] = (P_fixed * q_power[i-1]) >> 32;
                // fail after i balls
                T[i][100] = q_power[i];
            end
        end
    end

    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cost <= 64'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            step <= 32'd0;
            total_cost <= 64'd0;
            for (i = 0; i < 101; i = i + 1) begin
                prob[i] <= 32'd0;
                prob_next[i] <= 32'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE;
                        step <= 32'd0;
                        total_cost <= 64'd0;
                        // Initialize distribution
                        for (i = 0; i < 101; i = i + 1) begin
                            prob[i] <= 32'd0;
                        end
                        prob[100] <= 1 << 32;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Compute immediate cost
                    reg [63:0] cost_step = 64'd0;
                    for (i = 0; i < 101; i = i + 1) begin
                        cost_step = cost_step + (prob[i] * C[i]) >> 32;
                    end
                    total_cost = total_cost + cost_step;
                    
                    // Compute next distribution
                    for (j = 0; j < 101; j = j + 1) begin
                        prob_next[j] = 32'd0;
                        for (i = 0; i < 101; i = i + 1) begin
                            prob_next[j] = prob_next[j] + (prob[i] * T[i][j]) >> 32;
                        end
                    end
                    
                    // Update prob
                    for (i = 0; i < 101; i = i + 1) begin
                        prob[i] <= prob_next[i];
                    end
                    
                    step <= step + 32'd1;
                    
                    // Exit conditions
                    if (step >= N || cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    cost <= total_cost;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule