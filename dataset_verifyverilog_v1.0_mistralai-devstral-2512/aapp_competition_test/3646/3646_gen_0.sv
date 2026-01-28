module pebble_jump(
    input clk,
    input rst_n,
    input start,
    input [7:0] nodes_spots [0:15],
    input [3:0] num_nodes,
    output reg [3:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESS = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state;
    reg [15:0] reachable;  // Bitmask of reachable nodes
    reg [15:0] new_reachable;  // New nodes found in current iteration
    reg [3:0] current_max;  // Current maximum reachable node
    reg [9:0] cycle_count;  // Prevent infinite loops
    localparam [9:0] MAX_CYCLES = 10'd1000;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            reachable <= 16'd0;
            new_reachable <= 16'd0;
            current_max <= 4'd0;
            result <= 4'd0;
            done <= 1'b0;
            cycle_count <= 10'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 10'd0;
                    if (start) begin
                        state <= PROCESS;
                        reachable <= 16'd1;  // Start with node 0
                        current_max <= 4'd0;
                    end
                end
                
                PROCESS: begin
                    cycle_count <= cycle_count + 10'd1;
                    new_reachable <= 16'd0;
                    
                    // Check all pairs (u, v) where u is reachable
                    integer u;
                    integer v;
                    for (u = 0; u < 16; u = u + 1) begin
                        if (reachable[u]) begin
                            for (v = 0; v < num_nodes; v = v + 1) begin
                                if (!reachable[v]) begin
                                    // Check jump condition
                                    if (nodes_spots[u] + nodes_spots[v] == (u > v ? (u - v) : (v - u))) begin
                                        new_reachable[v] <= 1'b1;
                                    end
                                end
                            end
                        end
                    end
                    
                    // Update reachable set
                    reachable <= reachable | new_reachable;
                    
                    // Update current_max
                    if (new_reachable != 16'd0) begin
                        for (v = 15; v >= 0; v = v - 1) begin
                            if (new_reachable[v]) begin
                                current_max <= v;
                            end
                        end
                    end
                    
                    // Check if done
                    if (new_reachable == 16'd0 || cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    result <= current_max;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule