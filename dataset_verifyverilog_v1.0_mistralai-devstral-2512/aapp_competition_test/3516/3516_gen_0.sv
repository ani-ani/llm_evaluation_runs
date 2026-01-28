module min_time_mst(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [2:0] x_i [0:7],
    input wire [31:0] s_i [0:7],
    input wire [31:0] a_flat [0:63],
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE = 3'd1;
    localparam [2:0] FINISH = 3'd2;
    
    reg [2:0] state;
    reg [7:0] visited;
    reg [2:0] max_item;
    reg [31:0] total_cost;
    reg [3:0] node_count;
    reg [3:0] i;
    reg [3:0] j;
    reg [31:0] min_cost;
    reg [3:0] next_node;
    reg [3:0] k;
    reg [31:0] current_cost;
    reg [31:0] a [0:7][0:7];

    // Initialize a array
    integer idx;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (idx = 0; idx < 8; idx = idx + 1) begin
                for (j = 0; j < 8; j = j + 1) begin
                    a[idx][j] <= 32'd0;
                end
            end
        end else if (start && state == IDLE) begin
            for (idx = 0; idx < 8; idx = idx + 1) begin
                for (j = 0; j < 8; j = j + 1) begin
                    a[idx][j] <= a_flat[idx * 8 + j];
                end
            end
        end
    end

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            visited <= 8'd0;
            max_item <= 3'd0;
            total_cost <= 32'd0;
            node_count <= 4'd0;
            i <= 3'd0;
            j <= 3'd0;
            min_cost <= 32'd0;
            next_node <= 3'd0;
            k <= 3'd0;
            current_cost <= 32'd0;
            result <= 32'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= COMPUTE;
                        visited <= 8'd1;  // Start with node 0
                        max_item <= 3'd0;
                        total_cost <= 32'd0;
                        node_count <= 4'd1;
                    end
                end
                
                COMPUTE: begin
                    if (node_count < n) begin
                        // Find next node to add
                        min_cost <= 32'd0;
                        next_node <= 3'd0;
                        for (i = 0; i < 8; i = i + 1) begin
                            if (!visited[i] && i < n) begin
                                // Check normal edge
                                current_cost <= a[i][max_item];
                                
                                // Check shortcut edge if available
                                if (visited[x_i[i]] && s_i[i] < current_cost) begin
                                    current_cost <= s_i[i];
                                end
                                
                                // Update min cost
                                if (min_cost == 32'd0 || current_cost < min_cost) begin
                                    min_cost <= current_cost;
                                    next_node <= i;
                                end
                            end
                        end
                        
                        // Add node to visited set
                        visited <= visited | (1 << next_node);
                        total_cost <= total_cost + min_cost;
                        
                        // Update max_item
                        if (next_node > max_item) begin
                            max_item <= next_node;
                        end
                        
                        node_count <= node_count + 4'd1;
                    end else begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    result <= total_cost;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule