module polygon_counter #(
    parameter R = 4,
    parameter C = 4
)(
    input clk,
    input rst_n,
    input start,
    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] ENUMERATE = 3'd1;
    localparam [2:0] VALIDATE = 3'd2;
    localparam [2:0] DONE_STATE = 3'd3;

    // Internal registers
    reg [2:0] state;
    reg [15:0] mask;
    reg [15:0] max_mask;
    reg [15:0] cycle_count;
    localparam [15:0] MAX_CYCLES = 16'd65536;

    // For connectivity check
    reg [15:0] visited;
    reg [15:0] stack;
    reg [3:0] stack_ptr;
    reg [3:0] current_idx;
    reg [3:0] neighbor_idx;
    reg [3:0] r, c;
    reg [3:0] nr, nc;
    reg [3:0] i, j;
    reg [3:0] start_idx;
    reg [3:0] temp_idx;
    reg [3:0] border_start;
    reg [3:0] border_end;
    reg [3:0] border_step;
    reg [3:0] border_idx;

    // For hole check
    reg [15:0] background_visited;
    reg [15:0] background_stack;
    reg [3:0] background_stack_ptr;
    reg [3:0] background_current_idx;
    reg [3:0] background_neighbor_idx;
    reg [3:0] background_r, background_c;
    reg [3:0] background_nr, background_nc;

    // Flags
    reg is_valid;
    reg has_hole;
    reg is_empty;
    reg is_connected;

    // Initialize max_mask
    always @(*) begin
        max_mask = (1 << (R * C)) - 1;
    end

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            mask <= 16'd0;
            cycle_count <= 16'd0;
            visited <= 16'd0;
            stack <= 16'd0;
            stack_ptr <= 4'd0;
            current_idx <= 4'd0;
            neighbor_idx <= 4'd0;
            r <= 4'd0;
            c <= 4'd0;
            nr <= 4'd0;
            nc <= 4'd0;
            i <= 4'd0;
            j <= 4'd0;
            start_idx <= 4'd0;
            temp_idx <= 4'd0;
            border_start <= 4'd0;
            border_end <= 4'd0;
            border_step <= 4'd0;
            border_idx <= 4'd0;
            background_visited <= 16'd0;
            background_stack <= 16'd0;
            background_stack_ptr <= 4'd0;
            background_current_idx <= 4'd0;
            background_neighbor_idx <= 4'd0;
            background_r <= 4'd0;
            background_c <= 4'd0;
            background_nr <= 4'd0;
            background_nc <= 4'd0;
            is_valid <= 1'b0;
            has_hole <= 1'b0;
            is_empty <= 1'b0;
            is_connected <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 16'd0;
                    if (start) begin
                        state <= ENUMERATE;
                        mask <= 16'd0;
                        result <= 16'd0;
                    end
                end

                ENUMERATE: begin
                    cycle_count <= cycle_count + 16'd1;
                    if (mask == max_mask) begin
                        state <= DONE_STATE;
                    end else begin
                        state <= VALIDATE;
                    end
                end

                VALIDATE: begin
                    // Check if subset is empty
                    is_empty <= (mask == 16'd0);
                    
                    // Check connectivity
                    is_connected <= 1'b0;
                    visited <= 16'd0;
                    stack <= 16'd0;
                    stack_ptr <= 4'd0;
                    
                    // Find first set bit
                    for (i = 0; i < R*C; i = i + 1) begin
                        if (mask[i] && !is_connected) begin
                            start_idx <= i;
                            is_connected <= 1'b1;
                        end
                    end
                    
                    if (!is_empty && is_connected) begin
                        // Perform DFS for connectivity
                        stack[0] <= start_idx;
                        stack_ptr <= 4'd1;
                        visited[start_idx] <= 1'b1;
                        
                        for (i = 0; i < R*C; i = i + 1) begin
                            if (stack_ptr > 0) begin
                                current_idx <= stack[stack_ptr - 1];
                                stack_ptr <= stack_ptr - 1;
                                
                                r <= current_idx / C;
                                c <= current_idx % C;
                                
                                // Check neighbors
                                for (j = 0; j < 4; j = j + 1) begin
                                    case (j)
                                        0: begin nr <= r - 1; nc <= c; end    // up
                                        1: begin nr <= r + 1; nc <= c; end    // down
                                        2: begin nr <= r; nc <= c - 1; end    // left
                                        3: begin nr <= r; nc <= c + 1; end    // right
                                    endcase
                                    
                                    if (nr >= 0 && nr < R && nc >= 0 && nc < C) begin
                                        neighbor_idx <= nr * C + nc;
                                        if (mask[neighbor_idx] && !visited[neighbor_idx]) begin
                                            visited[neighbor_idx] <= 1'b1;
                                            stack[stack_ptr] <= neighbor_idx;
                                            stack_ptr <= stack_ptr + 1;
                                        end
                                    end
                                end
                            end
                        end
                        
                        // Check if all set bits are visited
                        is_connected <= 1'b1;
                        for (i = 0; i < R*C; i = i + 1) begin
                            if (mask[i] && !visited[i]) begin
                                is_connected <= 1'b0;
                            end
                        end
                    end
                    
                    // Check for holes
                    has_hole <= 1'b0;
                    background_visited <= 16'd0;
                    background_stack <= 16'd0;
                    background_stack_ptr <= 4'd0;
                    
                    if (is_connected) begin
                        // Initialize background_visited with border cells
                        for (i = 0; i < R; i = i + 1) begin
                            border_idx <= i * C;
                            background_visited[border_idx] <= 1'b1;  // left border
                            background_stack[background_stack_ptr] <= border_idx;
                            background_stack_ptr <= background_stack_ptr + 1;
                            
                            border_idx <= i * C + C - 1;
                            background_visited[border_idx] <= 1'b1;  // right border
                            background_stack[background_stack_ptr] <= border_idx;
                            background_stack_ptr <= background_stack_ptr + 1;
                        end
                        
                        for (i = 0; i < C; i = i + 1) begin
                            border_idx <= i;
                            background_visited[border_idx] <= 1'b1;  // top border
                            background_stack[background_stack_ptr] <= border_idx;
                            background_stack_ptr <= background_stack_ptr + 1;
                            
                            border_idx <= (R - 1) * C + i;
                            background_visited[border_idx] <= 1'b1;  // bottom border
                            background_stack[background_stack_ptr] <= border_idx;
                            background_stack_ptr <= background_stack_ptr + 1;
                        end
                        
                        // Perform BFS on background cells
                        for (i = 0; i < R*C; i = i + 1) begin
                            if (background_stack_ptr > 0) begin
                                background_current_idx <= background_stack[background_stack_ptr - 1];
                                background_stack_ptr <= background_stack_ptr - 1;
                                
                                background_r <= background_current_idx / C;
                                background_c <= background_current_idx % C;
                                
                                // Check neighbors
                                for (j = 0; j < 4; j = j + 1) begin
                                    case (j)
                                        0: begin background_nr <= background_r - 1; background_nc <= background_c; end    // up
                                        1: begin background_nr <= background_r + 1; background_nc <= background_c; end    // down
                                        2: begin background_nr <= background_r; background_nc <= background_c - 1; end    // left
                                        3: begin background_nr <= background_r; background_nc <= background_c + 1; end    // right
                                    endcase
                                    
                                    if (background_nr >= 0 && background_nr < R && background_nc >= 0 && background_nc < C) begin
                                        background_neighbor_idx <= background_nr * C + background_nc;
                                        if (!mask[background_neighbor_idx] && !background_visited[background_neighbor_idx]) begin
                                            background_visited[background_neighbor_idx] <= 1'b1;
                                            background_stack[background_stack_ptr] <= background_neighbor_idx;
                                            background_stack_ptr <= background_stack_ptr + 1;
                                        end
                                    end
                                end
                            end
                        end
                        
                        // Check if all background cells are visited
                        has_hole <= 1'b0;
                        for (i = 0; i < R*C; i = i + 1) begin
                            if (!mask[i] && !background_visited[i]) begin
                                has_hole <= 1'b1;
                            end
                        end
                    end
                    
                    // Determine validity
                    is_valid <= !is_empty && is_connected && !has_hole;
                    
                    if (is_valid) begin
                        result <= result + 16'd1;
                    end
                    
                    // Move to next mask
                    mask <= mask + 16'd1;
                    state <= ENUMERATE;
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule