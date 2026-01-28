module GraphColoringSolver(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [7:0] color_matrix [0:15][0:15],
    output reg [31:0] result,
    output reg done
);

    // Constants
    localparam [31:0] MOD = 32'd1000000007;
    localparam [15:0] MAX_SUBSETS = 16'd65535;
    localparam [15:0] MAX_CYCLES = 16'd10000;

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] PROCESS = 3'd2;
    localparam [2:0] DONE_STATE = 3'd3;

    // Internal registers
    reg [2:0] state, next_state;
    reg [15:0] subset_counter;
    reg [15:0] cycle_count;
    reg [3:0] current_n;
    reg [7:0] current_color_matrix [0:15][0:15];
    reg [31:0] accumulator;
    reg [15:0] current_subset;
    reg [3:0] max_clique_size;
    reg [3:0] temp_clique_size;
    reg [3:0] i, j, k;
    reg [15:0] temp_subset;
    reg monochromatic;
    reg [7:0] current_color;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            subset_counter <= 16'd0;
            cycle_count <= 16'd0;
            accumulator <= 32'd0;
            result <= 32'd0;
            done <= 1'b0;
            current_n <= 4'd0;
            for (i = 0; i < 16; i = i + 1) begin
                for (j = 0; j < 16; j = j + 1) begin
                    current_color_matrix[i][j] <= 8'd0;
                end
            end
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        next_state <= LOAD;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                LOAD: begin
                    current_n <= n;
                    for (i = 0; i < 16; i = i + 1) begin
                        for (j = 0; j < 16; j = j + 1) begin
                            current_color_matrix[i][j] <= color_matrix[i][j];
                        end
                    end
                    subset_counter <= 16'd0;
                    accumulator <= 32'd0;
                    next_state <= PROCESS;
                end

                PROCESS: begin
                    cycle_count <= cycle_count + 16'd1;
                    
                    // Generate next subset
                    if (subset_counter == 16'd0) begin
                        current_subset <= 16'd1; // Start with subset {0}
                    end else begin
                        current_subset <= subset_counter + 16'd1;
                    end
                    
                    // Calculate f(S) for current_subset
                    max_clique_size <= 4'd0;
                    
                    // Check all possible sub-subsets (cliques)
                    temp_subset <= 16'd1;
                    repeat (16'd65536) begin
                        if (temp_subset != 16'd0) begin
                            // Check if temp_subset is a clique
                            monochromatic <= 1'b1;
                            current_color <= 8'd0;
                            
                            // Find first node in subset
                            for (i = 0; i < 16; i = i + 1) begin
                                if (temp_subset[i]) begin
                                    current_color <= current_color_matrix[i][i]; // Should be 0, but we'll use first edge
                                    break;
                                end
                            end
                            
                            // Check all edges in temp_subset
                            for (i = 0; i < 16; i = i + 1) begin
                                if (temp_subset[i]) begin
                                    for (j = i + 1; j < 16; j = j + 1) begin
                                        if (temp_subset[j]) begin
                                            if (current_color_matrix[i][j] != current_color) begin
                                                monochromatic <= 1'b0;
                                            end
                                        end
                                    end
                                end
                            end
                            
                            // Count size if monochromatic
                            if (monochromatic) begin
                                temp_clique_size <= 4'd0;
                                for (i = 0; i < 16; i = i + 1) begin
                                    if (temp_subset[i]) begin
                                        temp_clique_size <= temp_clique_size + 4'd1;
                                    end
                                end
                                
                                if (temp_clique_size > max_clique_size) begin
                                    max_clique_size <= temp_clique_size;
                                end
                            end
                            
                            // Generate next subset
                            temp_subset <= temp_subset + 16'd1;
                        end
                    end
                    
                    // Add to accumulator
                    accumulator <= (accumulator + max_clique_size) % MOD;
                    
                    // Move to next subset
                    subset_counter <= subset_counter + 16'd1;
                    
                    // Check if done
                    if (subset_counter >= (16'd1 << current_n) - 16'd1 || cycle_count >= MAX_CYCLES) begin
                        next_state <= DONE_STATE;
                    end else begin
                        next_state <= PROCESS;
                    end
                end

                DONE_STATE: begin
                    result <= accumulator;
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

    // Default assignments for unused registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            i <= 4'd0;
            j <= 4'd0;
            k <= 4'd0;
            temp_clique_size <= 4'd0;
            temp_subset <= 16'd0;
            monochromatic <= 1'b0;
            current_color <= 8'd0;
        end
    end

endmodule