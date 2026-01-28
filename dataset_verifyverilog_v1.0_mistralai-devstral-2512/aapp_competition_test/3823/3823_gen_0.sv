module RoundingOptimizer(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] n,
    input wire [15:0] data_in,
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] LOAD_N    = 3'd1;
    localparam [2:0] LOAD_DATA = 3'd2;
    localparam [2:0] COMPUTE   = 3'd3;
    localparam [2:0] FINISH    = 3'd4;

    reg [2:0] state;
    reg [15:0] n_reg;
    reg [15:0] data_reg;
    reg [15:0] total_fractions;
    reg [15:0] K;
    reg [15:0] S;
    reg [15:0] min_diff;
    reg [15:0] current_p;
    reg [15:0] cycle_count;
    reg [15:0] data_counter;
    reg [15:0] i;
    reg [15:0] j;
    reg [15:0] temp_diff;
    reg [15:0] temp_sum;
    reg [15:0] temp_p;
    reg [15:0] temp_S;
    reg [15:0] temp_K;
    reg [15:0] temp_n;
    reg [15:0] temp_min_diff;
    reg [15:0] temp_current_p;
    reg [15:0] temp_cycle_count;
    reg [15:0] temp_data_counter;
    reg [15:0] temp_i;
    reg [15:0] temp_j;

    // DP array (simplified to 1D rolling array)
    reg signed [15:0] dp_prev [0:2047];
    reg signed [15:0] dp_curr [0:2047];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            n_reg <= 16'd0;
            data_reg <= 16'd0;
            total_fractions <= 16'd0;
            K <= 16'd0;
            S <= 16'd0;
            min_diff <= 16'd0;
            current_p <= 16'd0;
            cycle_count <= 16'd0;
            data_counter <= 16'd0;
            i <= 16'd0;
            j <= 16'd0;
            temp_diff <= 16'd0;
            temp_sum <= 16'd0;
            temp_p <= 16'd0;
            temp_S <= 16'd0;
            temp_K <= 16'd0;
            temp_n <= 16'd0;
            temp_min_diff <= 16'd0;
            temp_current_p <= 16'd0;
            temp_cycle_count <= 16'd0;
            temp_data_counter <= 16'd0;
            temp_i <= 16'd0;
            temp_j <= 16'd0;
            done <= 1'b0;
            result <= 32'd0;
            
            // Initialize DP arrays
            integer k;
            for (k = 0; k < 2048; k = k + 1) begin
                dp_prev[k] <= 16'd0;
                dp_curr[k] <= 16'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= LOAD_N;
                    end
                end

                LOAD_N: begin
                    n_reg <= n;
                    total_fractions <= 16'd0;
                    K <= 16'd0;
                    S <= 16'd0;
                    data_counter <= 16'd0;
                    state <= LOAD_DATA;
                end

                LOAD_DATA: begin
                    data_reg <= data_in;
                    
                    // Check if fraction is non-zero (non-integer)
                    if (data_reg != 16'd0) begin
                        K <= K + 16'd1;
                        S <= S + data_reg;
                    end
                    
                    data_counter <= data_counter + 16'd1;
                    
                    if (data_counter == n_reg) begin
                        state <= COMPUTE;
                        i <= 16'd0;
                        j <= 16'd0;
                        
                        // Initialize DP arrays
                        integer k;
                        for (k = 0; k < 2048; k = k + 1) begin
                            dp_prev[k] <= 16'd0;
                            dp_curr[k] <= 16'd0;
                        end
                        
                        // Initialize first row
                        dp_prev[0] <= 16'd0;
                        for (k = 1; k < 2048; k = k + 1) begin
                            dp_prev[k] <= 16'd32767; // Large value
                        end
                    end
                end

                COMPUTE: begin
                    // DP computation
                    if (i < n_reg) begin
                        // Get current fraction
                        temp_sum <= data_reg;
                        
                        // Update DP array
                        dp_curr[0] <= dp_prev[0];
                        for (j = 1; j <= i + 16'd1; j = j + 1) begin
                            if (j > i) begin
                                dp_curr[j] <= dp_prev[j - 16'd1] + temp_sum;
                            end else begin
                                if (dp_prev[j] < dp_prev[j - 16'd1] + temp_sum) begin
                                    dp_curr[j] <= dp_prev[j];
                                end else begin
                                    dp_curr[j] <= dp_prev[j - 16'd1] + temp_sum;
                                end
                            end
                        end
                        
                        // Copy current to previous
                        for (j = 0; j < 2048; j = j + 1) begin
                            dp_prev[j] <= dp_curr[j];
                        end
                        
                        i <= i + 16'd1;
                    end else begin
                        // Find minimal difference
                        min_diff <= 16'd32767;
                        temp_n <= n_reg;
                        temp_K <= K;
                        temp_S <= S;
                        
                        for (current_p = 16'd0; current_p <= temp_K; current_p = current_p + 16'd1) begin
                            if (current_p <= temp_n) begin
                                temp_diff <= temp_S - current_p;
                                if (temp_diff < 16'd0) begin
                                    temp_diff <= -temp_diff;
                                end
                                
                                if (temp_diff < min_diff) begin
                                    min_diff <= temp_diff;
                                end
                            end
                        end
                        
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    // Convert to Q16.16 format
                    result <= {16'd0, min_diff};
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule