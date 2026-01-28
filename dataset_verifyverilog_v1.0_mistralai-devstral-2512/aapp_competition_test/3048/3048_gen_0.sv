module OptimalPathCounter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] adj_matrix [0:15],
    output reg [15:0] result,
    output reg done
);
    
    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] COMPUTE_DEGREES = 3'd1;
    localparam [2:0] COMPUTE_SUM = 3'd2;
    localparam [2:0] FINISH  = 3'd3;
    
    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;
    
    // Degree storage (4-bit per node, max 15)
    reg [3:0] degrees [0:15];
    reg [7:0] current_node;
    reg [7:0] neighbor_index;
    reg [15:0] sum;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            current_node <= 8'd0;
            neighbor_index <= 8'd0;
            sum <= 16'd0;
            
            // Initialize degrees array
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                degrees[i] <= 4'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE_DEGREES;
                        current_node <= 8'd0;
                        neighbor_index <= 8'd0;
                        sum <= 16'd0;
                    end
                end
                
                COMPUTE_DEGREES: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Compute degree for current_node
                    if (neighbor_index < 16) begin
                        if (adj_matrix[current_node][neighbor_index]) begin
                            degrees[current_node] <= degrees[current_node] + 4'd1;
                        end
                        neighbor_index <= neighbor_index + 8'd1;
                    end else begin
                        // Move to next node
                        current_node <= current_node + 8'd1;
                        neighbor_index <= 8'd0;
                        
                        // Check if all nodes processed
                        if (current_node >= 16) begin
                            state <= COMPUTE_SUM;
                            current_node <= 8'd0;
                        end
                    end
                end
                
                COMPUTE_SUM: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Compute deg[i]*(deg[i]-1) for current node
                    if (current_node < 16) begin
                        reg [7:0] deg_val;
                        deg_val = degrees[current_node];
                        
                        reg [15:0] product;
                        product = deg_val * (deg_val - 4'd1);
                        
                        sum <= sum + product;
                        current_node <= current_node + 8'd1;
                    end else begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    result <= sum;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule