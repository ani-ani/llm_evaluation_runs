module team_selector(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [4:0] n,
    input wire [3:0] p,
    input wire [3:0] s,
    input wire [11:0] a [0:19],
    input wire [11:0] b [0:19],
    output reg [15:0] result,
    output reg [4:0] team_p [0:9],
    output reg [4:0] team_s [0:9],
    output reg done,
    output reg valid
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] SORT = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] FINISH = 3'd3;
    
    reg [2:0] state;
    reg [9:0] cycle_count;
    localparam [9:0] MAX_CYCLES = 10'd1000;

    // Internal registers for sorted data
    reg [11:0] sorted_a [0:19];
    reg [11:0] sorted_b [0:19];
    reg [4:0] sorted_idx [0:19];

    // Sorting variables
    reg [4:0] i, j;
    reg [11:0] temp_a, temp_b;
    reg [4:0] temp_idx;

    // Computation variables
    reg [15:0] prefix_sum_a [0:19];
    reg [15:0] current_total;
    reg [15:0] max_total;
    reg [4:0] best_k;
    reg [4:0] k;
    reg [4:0] converter_count;
    reg [11:0] conversion_gain [0:9];
    reg [11:0] remaining_b_sum;

    // Team assignment variables
    reg [4:0] p_idx, s_idx;
    reg [4:0] converter_idx;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            valid <= 1'b0;
            cycle_count <= 10'd0;
            
            // Initialize all team outputs to 0
            for (i = 0; i < 10; i = i + 1) begin
                team_p[i] <= 5'd0;
                team_s[i] <= 5'd0;
            end
            
            // Initialize sorting arrays
            for (i = 0; i < 20; i = i + 1) begin
                sorted_a[i] <= 12'd0;
                sorted_b[i] <= 12'd0;
                sorted_idx[i] <= 5'd0;
            end
            
            // Initialize computation variables
            for (i = 0; i < 20; i = i + 1) begin
                prefix_sum_a[i] <= 16'd0;
            end
            
            max_total <= 16'd0;
            best_k <= 5'd0;
            
            i <= 5'd0;
            j <= 5'd0;
            k <= 5'd0;
            p_idx <= 5'd0;
            s_idx <= 5'd0;
            converter_idx <= 5'd0;
            
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    cycle_count <= 10'd0;
                    
                    if (start) begin
                        state <= SORT;
                        
                        // Initialize sorted arrays with input data
                        for (i = 0; i < 20; i = i + 1) begin
                            if (i < n) begin
                                sorted_a[i] <= a[i];
                                sorted_b[i] <= b[i];
                                sorted_idx[i] <= i + 5'd1;
                            end else begin
                                sorted_a[i] <= 12'd0;
                                sorted_b[i] <= 12'd0;
                                sorted_idx[i] <= 5'd0;
                            end
                        end
                        
                        i <= 5'd0;
                        j <= 5'd0;
                    end
                end

                SORT: begin
                    cycle_count <= cycle_count + 10'd1;
                    
                    // Bubble sort by a descending
                    if (i < n - 5'd1) begin
                        if (j < n - i - 5'd1) begin
                            if (sorted_a[j] < sorted_a[j + 5'd1]) begin
                                // Swap a
                                temp_a <= sorted_a[j];
                                sorted_a[j] <= sorted_a[j + 5'd1];
                                sorted_a[j + 5'd1] <= temp_a;
                                
                                // Swap b
                                temp_b <= sorted_b[j];
                                sorted_b[j] <= sorted_b[j + 5'd1];
                                sorted_b[j + 5'd1] <= temp_b;
                                
                                // Swap indices
                                temp_idx <= sorted_idx[j];
                                sorted_idx[j] <= sorted_idx[j + 5'd1];
                                sorted_idx[j + 5'd1] <= temp_idx;
                            end
                            j <= j + 5'd1;
                        end else begin
                            j <= 5'd0;
                            i <= i + 5'd1;
                        end
                    end else begin
                        // Sorting complete, compute prefix sums
                        prefix_sum_a[0] <= sorted_a[0];
                        for (i = 1; i < 20; i = i + 1) begin
                            if (i < n) begin
                                prefix_sum_a[i] <= prefix_sum_a[i - 5'd1] + sorted_a[i];
                            end else begin
                                prefix_sum_a[i] <= prefix_sum_a[i - 5'd1];
                            end
                        end
                        
                        state <= COMPUTE;
                        k <= p;
                        max_total <= 16'd0;
                        best_k <= 5'd0;
                    end
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 10'd1;
                    
                    // Compute for current k
                    converter_count <= k - p;
                    
                    // Compute conversion gain (top converter_count from first k)
                    // Find top converters by (b-a) among first k students
                    for (i = 0; i < 10; i = i + 1) begin
                        conversion_gain[i] <= 12'd0;
                    end
                    
                    for (i = 0; i < k; i = i + 1) begin
                        for (j = 0; j < converter_count; j = j + 1) begin
                            if ((sorted_b[i] - sorted_a[i]) > conversion_gain[j]) begin
                                // Shift and insert
                                for (converter_idx = converter_count - 5'd1; converter_idx > j; converter_idx = converter_idx - 5'd1) begin
                                    conversion_gain[converter_idx] <= conversion_gain[converter_idx - 5'd1];
                                end
                                conversion_gain[j] <= sorted_b[i] - sorted_a[i];
                                break;
                            end
                        end
                    end
                    
                    // Sum conversion gains
                    current_total <= prefix_sum_a[k - 5'd1];
                    for (i = 0; i < converter_count; i = i + 1) begin
                        current_total <= current_total + conversion_gain[i];
                    end
                    
                    // Compute remaining_b_sum (last s - converter_count students)
                    remaining_b_sum <= 12'd0;
                    for (i = k; i < n; i = i + 1) begin
                        if ((i - k) < (s - converter_count)) begin
                            remaining_b_sum <= remaining_b_sum + sorted_b[i];
                        end
                    end
                    current_total <= current_total + remaining_b_sum;
                    
                    // Update max
                    if (current_total > max_total) begin
                        max_total <= current_total;
                        best_k <= k;
                    end
                    
                    // Move to next k
                    if (k < p + s) begin
                        k <= k + 5'd1;
                    end else begin
                        state <= FINISH;
                        result <= max_total;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    valid <= 1'b1;
                    
                    // Assign teams
                    converter_count <= best_k - p;
                    
                    // Programming team: top converter_count converters + rest to fill p
                    p_idx <= 5'd0;
                    for (i = 0; i < best_k; i = i + 1) begin
                        if (p_idx < p) begin
                            team_p[p_idx] <= sorted_idx[i];
                            p_idx <= p_idx + 5'd1;
                        end
                    end
                    
                    // Sports team: remaining students
                    s_idx <= 5'd0;
                    for (i = best_k; i < n; i = i + 1) begin
                        if (s_idx < s) begin
                            team_s[s_idx] <= sorted_idx[i];
                            s_idx <= s_idx + 5'd1;
                        end
                    end
                    
                    // Pad remaining team slots with 0
                    for (i = p_idx; i < 10; i = i + 1) begin
                        team_p[i] <= 5'd0;
                    end
                    for (i = s_idx; i < 10; i = i + 1) begin
                        team_s[i] <= 5'd0;
                    end
                    
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                    valid <= 1'b0;
                end
            endcase
            
            // Safety: prevent infinite loops
            if (cycle_count >= MAX_CYCLES) begin
                state <= IDLE;
                done <= 1'b0;
                valid <= 1'b0;
            end
        end
    end
endmodule