module TreeConnectivity(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [3:0] h,
    input wire [3:0] edge_a,
    input wire [3:0] edge_b,
    input wire edge_valid,
    output reg [3:0] m,
    output reg [3:0] edge_out_a,
    output reg [3:0] edge_out_b,
    output reg out_valid,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE        = 3'd0;
    localparam [2:0] READ_EDGES  = 3'd1;
    localparam [2:0] CALC_LEAVES = 3'd2;
    localparam [2:0] OUTPUT_EDGES = 3'd3;
    localparam [2:0] FINISH      = 3'd4;

    // Internal registers
    reg [2:0] state, next_state;
    reg [3:0] degree [0:15];  // Degree count for each node (0-15)
    reg [3:0] leaf_list [0:15]; // List of leaf nodes
    reg [3:0] leaf_count;       // Number of leaves found
    reg [3:0] edge_counter;     // Counter for input edges
    reg [3:0] output_counter;   // Counter for output edges
    reg [3:0] current_leaf_idx; // Index into leaf_list for output
    reg [7:0] cycle_counter;    // Prevent infinite loops
    localparam [7:0] MAX_CYCLES = 8'd100;

    integer i;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            m <= 4'd0;
            edge_out_a <= 4'd0;
            edge_out_b <= 4'd0;
            out_valid <= 1'b0;
            done <= 1'b0;
            leaf_count <= 4'd0;
            edge_counter <= 4'd0;
            output_counter <= 4'd0;
            current_leaf_idx <= 4'd0;
            cycle_counter <= 8'd0;
            for (i = 0; i < 16; i = i + 1) begin
                degree[i] <= 4'd0;
                leaf_list[i] <= 4'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    out_valid <= 1'b0;
                    cycle_counter <= 8'd0;
                    if (start) begin
                        // Initialize degree counters
                        for (i = 0; i < 16; i = i + 1) begin
                            degree[i] <= 4'd0;
                            leaf_list[i] <= 4'd0;
                        end
                        leaf_count <= 4'd0;
                        edge_counter <= 4'd0;
                    end
                end
                
                READ_EDGES: begin
                    cycle_counter <= cycle_counter + 8'd1;
                    if (edge_valid && (edge_counter < (n - 4'd1))) begin
                        // Update degrees
                        degree[edge_a] <= degree[edge_a] + 4'd1;
                        degree[edge_b] <= degree[edge_b] + 4'd1;
                        edge_counter <= edge_counter + 4'd1;
                    end
                end
                
                CALC_LEAVES: begin
                    cycle_counter <= cycle_counter + 8'd1;
                    // This state will be processed in next_state logic
                    // Data update happens in OUTPUT_EDGES or FINISH
                end
                
                OUTPUT_EDGES: begin
                    out_valid <= 1'b1;
                    edge_out_a <= leaf_list[current_leaf_idx];
                    edge_out_b <= h;
                    output_counter <= output_counter + 4'd1;
                    current_leaf_idx <= current_leaf_idx + 4'd1;
                end
                
                FINISH: begin
                    out_valid <= 1'b0;
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                    out_valid <= 1'b0;
                end
            endcase
        end
    end

    // Next state and output logic
    always @(*) begin
        next_state = state;
        
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = READ_EDGES;
                end
            end
            
            READ_EDGES: begin
                // Continue reading until we have N-1 edges or timeout
                if ((edge_counter >= (n - 4'd1)) || (cycle_counter >= MAX_CYCLES)) begin
                    next_state = CALC_LEAVES;
                end
            end
            
            CALC_LEAVES: begin
                // Find leaves: nodes with degree 1, exclude headquarters h
                leaf_count = 4'd0;
                for (i = 0; i < 16; i = i + 1) begin
                    if ((i < n) && (degree[i] == 4'd1) && (i != h)) begin
                        leaf_list[leaf_count] = i[3:0];
                        leaf_count = leaf_count + 4'd1;
                    end
                end
                m = leaf_count;
                next_state = OUTPUT_EDGES;
            end
            
            OUTPUT_EDGES: begin
                // Output edges until all leaves are processed
                if ((output_counter >= leaf_count) || (cycle_counter >= MAX_CYCLES)) begin
                    next_state = FINISH;
                end
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule