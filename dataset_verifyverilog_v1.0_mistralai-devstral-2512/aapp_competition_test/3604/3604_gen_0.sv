module MaxCliqueSensorNetwork(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] sensor_x [0:7],
    input wire [15:0] sensor_y [0:7],
    input wire [15:0] d,
    output reg done,
    output reg [3:0] size,
    output reg [31:0] indices
);

    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] READ = 3'd1;
    localparam [2:0] COMPUTE_ADJ = 3'd2;
    localparam [2:0] FIND_CLIQUE = 3'd3;
    localparam [2:0] OUTPUT = 3'd4;
    
    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd256;
    
    reg [15:0] x_reg [0:7];
    reg [15:0] y_reg [0:7];
    reg [15:0] d_reg;
    reg [3:0] n;
    
    reg adj [0:7][0:7];
    reg [3:0] current_size;
    reg [3:0] max_size;
    reg [3:0] current_indices [0:7];
    reg [3:0] best_indices [0:7];
    
    reg [3:0] i, j, k, m;
    reg [3:0] test_indices [0:7];
    reg [3:0] test_size;
    reg is_clique;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            size <= 4'd0;
            indices <= 32'd0;
            cycle_count <= 8'd0;
            
            for (i = 0; i < 8; i = i + 1) begin
                x_reg[i] <= 16'd0;
                y_reg[i] <= 16'd0;
                for (j = 0; j < 8; j = j + 1) begin
                    adj[i][j] <= 1'b0;
                end
            end
            
            current_size <= 4'd0;
            max_size <= 4'd0;
            for (i = 0; i < 8; i = i + 1) begin
                current_indices[i] <= 4'd0;
                best_indices[i] <= 4'd0;
            end
            
            i <= 4'd0;
            j <= 4'd0;
            k <= 4'd0;
            m <= 4'd0;
            test_size <= 4'd0;
            is_clique <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= READ;
                    end
                end
                
                READ: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    n <= 4'd0;
                    for (i = 0; i < 8; i = i + 1) begin
                        if (sensor_x[i] != 16'd0 || sensor_y[i] != 16'd0) begin
                            n <= n + 4'd1;
                        end
                    end
                    
                    for (i = 0; i < 8; i = i + 1) begin
                        x_reg[i] <= sensor_x[i];
                        y_reg[i] <= sensor_y[i];
                    end
                    d_reg <= d;
                    
                    state <= COMPUTE_ADJ;
                end
                
                COMPUTE_ADJ: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (i < n) begin
                        if (j < n) begin
                            if (i != j) begin
                                reg signed [15:0] x_diff, y_diff;
                                reg [31:0] dist_sq, d_sq;
                                
                                x_diff <= x_reg[i] - x_reg[j];
                                y_diff <= y_reg[i] - y_reg[j];
                                
                                dist_sq <= $signed(x_diff) * $signed(x_diff) + 
                                          $signed(y_diff) * $signed(y_diff);
                                d_sq <= $signed(d_reg) * $signed(d_reg);
                                
                                adj[i][j] <= (dist_sq <= d_sq);
                            end else begin
                                adj[i][j] <= 1'b1;
                            end
                            j <= j + 4'd1;
                        end else begin
                            j <= 4'd0;
                            i <= i + 4'd1;
                        end
                    end else begin
                        i <= 4'd0;
                        j <= 4'd0;
                        state <= FIND_CLIQUE;
                    end
                end
                
                FIND_CLIQUE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (current_size < n) begin
                        if (test_size < current_size + 4'd1) begin
                            if (test_size == 4'd0) begin
                                test_indices[0] <= k;
                                test_size <= test_size + 4'd1;
                                k <= k + 4'd1;
                            end else begin
                                if (k < n) begin
                                    reg found;
                                    found <= 1'b0;
                                    
                                    for (m = 0; m < test_size; m = m + 1) begin
                                        if (!found && adj[k][test_indices[m]]) begin
                                            found <= 1'b1;
                                        end
                                    end
                                    
                                    if (found) begin
                                        test_indices[test_size] <= k;
                                        test_size <= test_size + 4'd1;
                                    end
                                    k <= k + 4'd1;
                                end else begin
                                    k <= 4'd0;
                                    test_size <= 4'd0;
                                    current_size <= current_size + 4'd1;
                                end
                            end
                        end else begin
                            is_clique <= 1'b1;
                            for (i = 0; i < test_size; i = i + 1) begin
                                for (j = i + 4'd1; j < test_size; j = j + 1) begin
                                    if (!adj[test_indices[i]][test_indices[j]]) begin
                                        is_clique <= 1'b0;
                                    end
                                end
                            end
                            
                            if (is_clique && test_size > max_size) begin
                                max_size <= test_size;
                                for (i = 0; i < test_size; i = i + 1) begin
                                    best_indices[i] <= test_indices[i];
                                end
                            end
                            
                            test_size <= 4'd0;
                            k <= 4'd0;
                            current_size <= current_size + 4'd1;
                        end
                    end else begin
                        state <= OUTPUT;
                    end
                end
                
                OUTPUT: begin
                    done <= 1'b1;
                    size <= max_size;
                    
                    indices <= 32'd0;
                    for (i = 0; i < max_size; i = i + 1) begin
                        indices[4*i + 3:4*i] <= best_indices[i] + 4'd1;
                    end
                    
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
            
            if (cycle_count >= MAX_CYCLES) begin
                state <= IDLE;
            end
        end
    end
endmodule