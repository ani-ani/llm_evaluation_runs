module teacher_reassignment(
    input clk,
    input rst_n,
    input start,
    input [0:15] q_type,
    input [0:15][3:0] q_x,
    input [0:15][3:0] q_k_or_d,
    input [0:15][15:0] q_params,
    output reg [0:15][3:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] PROCESS = 3'd1;
    localparam [2:0] FINISH = 3'd2;
    
    reg [2:0] state;
    reg [7:0] query_index;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd1000;

    // Arrays for teacher-to-class mapping and query results
    reg [3:0] teacher_to_class [0:15];
    reg [3:0] query_results [0:15];

    // Internal signals
    reg [3:0] current_k;
    reg [3:0] current_d;
    reg [3:0] current_x;
    reg [3:0] current_teacher;
    reg [3:0] current_class;
    reg [3:0] temp_teacher;
    reg [3:0] temp_class;
    reg [3:0] rotation_list [0:9];
    reg [3:0] rotation_index;
    reg [3:0] rotation_size;
    reg [3:0] rotation_temp;
    reg [3:0] i;
    reg [3:0] j;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            query_index <= 8'd0;
            cycle_count <= 8'd0;
            done <= 1'b0;
            
            // Initialize teacher_to_class to identity
            for (i = 0; i < 16; i = i + 1) begin
                teacher_to_class[i] <= i + 1;
            end
            
            // Initialize query_results to 0
            for (i = 0; i < 16; i = i + 1) begin
                query_results[i] <= 4'd0;
            end
            
            // Initialize result to 0
            for (i = 0; i < 16; i = i + 1) begin
                result[i] <= 4'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= PROCESS;
                        query_index <= 8'd0;
                    end
                end
                
                PROCESS: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Process current query
                    if (query_index < 16) begin
                        if (q_type[query_index] == 1'b0) begin
                            // Rotation query
                            current_k <= q_k_or_d[query_index];
                            current_x <= q_x[query_index];
                            
                            // Extract rotation list from q_params
                            for (i = 0; i < 10; i = i + 1) begin
                                rotation_list[i] <= q_params[query_index][(i*4)+3:i*4];
                            end
                            
                            // Perform rotation
                            rotation_size <= current_k;
                            for (i = 0; i < rotation_size; i = i + 1) begin
                                rotation_temp <= teacher_to_class[rotation_list[rotation_size-1]-1];
                                for (j = rotation_size-1; j > 0; j = j - 1) begin
                                    teacher_to_class[rotation_list[j]-1] <= teacher_to_class[rotation_list[j-1]-1];
                                end
                                teacher_to_class[rotation_list[0]-1] <= rotation_temp;
                            end
                            
                            query_index <= query_index + 8'd1;
                        end else begin
                            // Question query
                            current_d <= q_k_or_d[query_index];
                            current_x <= q_x[query_index];
                            
                            // Store result
                            query_results[query_index] <= teacher_to_class[current_d-1];
                            
                            query_index <= query_index + 8'd1;
                        end
                    end else begin
                        // All queries processed
                        state <= FINISH;
                    end
                    
                    // Safety: prevent infinite loops
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    
                    // Copy query_results to result
                    for (i = 0; i < 16; i = i + 1) begin
                        result[i] <= query_results[i];
                    end
                    
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule