module OptimalPaths(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] adj_matrix [0:15],  // 16x16 bit adjacency matrix
    output reg [15:0] result,
    output reg done
);
    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] DEG_COUNT = 3'd1;
    localparam [2:0] SUM_CALC = 3'd2;
    localparam [2:0] FINISH = 3'd3;
    localparam [2:0] ERROR = 3'd4;

    // Internal registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [3:0] node_idx;  // 0-15 for nodes
    reg [3:0] col_idx;   // 0-15 for adjacency matrix columns
    reg [3:0] degree;    // Current node degree (0-15)
    reg [15:0] temp_sum; // Accumulated sum
    reg [15:0] node_degrees [0:15]; // Store all degrees
    reg [3:0] cycle_count; // For processing timing
    reg processing_started; // Flag to track start

    // Edge detection for start signal
    reg start_prev;
    wire start_pulse;
    assign start_pulse = start && !start_prev;

    // Combinational degree calculation for current node
    wire [3:0] current_degree;
    assign current_degree = (adj_matrix[node_idx][0] ? 4'd1 : 4'd0) +
                           (adj_matrix[node_idx][1] ? 4'd1 : 4'd0) +
                           (adj_matrix[node_idx][2] ? 4'd1 : 4'd0) +
                           (adj_matrix[node_idx][3] ? 4'd1 : 4'd0) +
                           (adj_matrix[node_idx][4] ? 4'd1 : 4'd0) +
                           (adj_matrix[node_idx][5] ? 4'd1 : 4'd0) +
                           (adj_matrix[node_idx][6] ? 4'd1 : 4'd0) +
                           (adj_matrix[node_idx][7] ? 4'd1 : 4'd0) +
                           (adj_matrix[node_idx][8] ? 4'd1 : 4'd0) +
                           (adj_matrix[node_idx][9] ? 4'd1 : 4'd0) +
                           (adj_matrix[node_idx][10] ? 4'd1 : 4'd0) +
                           (adj_matrix[node_idx][11] ? 4'd1 : 4'd0) +
                           (adj_matrix[node_idx][12] ? 4'd1 : 4'd0) +
                           (adj_matrix[node_idx][13] ? 4'd1 : 4'd0) +
                           (adj_matrix[node_idx][14] ? 4'd1 : 4'd0) +
                           (adj_matrix[node_idx][15] ? 4'd1 : 4'd0);

    // Combinational term calculation: deg*(deg-1)
    wire [15:0] term;
    wire [7:0] deg_minus_1;
    assign deg_minus_1 = (degree == 4'd0) ? 8'd0 : (degree - 4'd1);
    assign term = {8'd0, degree} * {8'd0, deg_minus_1};

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start_pulse) next_state = DEG_COUNT;
            end
            DEG_COUNT: begin
                if (node_idx == 4'd15 && cycle_count == 4'd15) next_state = SUM_CALC;
            end
            SUM_CALC: begin
                if (node_idx == 4'd15) next_state = FINISH;
            end
            FINISH: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Asynchronous reset
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            node_idx <= 4'd0;
            col_idx <= 4'd0;
            degree <= 4'd0;
            temp_sum <= 16'd0;
            cycle_count <= 4'd0;
            start_prev <= 1'b0;
            processing_started <= 1'b0;
            // Initialize node_degrees array
            node_degrees[0] <= 16'd0;
            node_degrees[1] <= 16'd0;
            node_degrees[2] <= 16'd0;
            node_degrees[3] <= 16'd0;
            node_degrees[4] <= 16'd0;
            node_degrees[5] <= 16'd0;
            node_degrees[6] <= 16'd0;
            node_degrees[7] <= 16'd0;
            node_degrees[8] <= 16'd0;
            node_degrees[9] <= 16'd0;
            node_degrees[10] <= 16'd0;
            node_degrees[11] <= 16'd0;
            node_degrees[12] <= 16'd0;
            node_degrees[13] <= 16'd0;
            node_degrees[14] <= 16'd0;
            node_degrees[15] <= 16'd0;
        end else begin
            start_prev <= start;
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    // Clear flags
                    processing_started <= 1'b0;
                    cycle_count <= 4'd0;
                    if (start_pulse) begin
                        node_idx <= 4'd0;
                        col_idx <= 4'd0;
                        degree <= 4'd0;
                        temp_sum <= 16'd0;
                        processing_started <= 1'b1;
                    end
                end
                
                DEG_COUNT: begin
                    // Calculate degree for each node
                    // Use current_degree to compute degree
                    degree <= current_degree;
                    node_degrees[node_idx] <= {12'd0, current_degree};
                    
                    // Move to next node
                    if (node_idx == 4'd15 && cycle_count == 4'd15) begin
                        node_idx <= 4'd0;
                        cycle_count <= 4'd0;
                    end else if (cycle_count == 4'd15) begin
                        node_idx <= node_idx + 4'd1;
                        cycle_count <= 4'd0;
                    end else begin
                        cycle_count <= cycle_count + 4'd1;
                    end
                end
                
                SUM_CALC: begin
                    // Calculate sum of deg[i]*(deg[i]-1)
                    temp_sum <= temp_sum + term;
                    node_idx <= node_idx + 4'd1;
                end
                
                FINISH: begin
                    result <= temp_sum;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
            
            state <= next_state;
        end
    end
endmodule