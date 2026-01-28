module RectangleMatcher(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] tl_r_i [0:63],
    input wire [15:0] tl_c_i [0:63],
    input wire [15:0] br_r_i [0:63],
    input wire [15:0] br_c_i [0:63],
    output reg result_valid,
    output reg [7:0] match_index [0:63],
    output reg syntax_error
);

    // State definitions
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] LOAD = 4'd1;
    localparam [3:0] SORT = 4'd2;
    localparam [3:0] VALIDATE = 4'd3;
    localparam [3:0] OUTPUT = 4'd4;
    localparam [3:0] DONE = 4'd5;

    reg [3:0] state, next_state;
    reg [9:0] cycle_count;
    localparam [9:0] MAX_CYCLES = 10'd1000;

    // Corner storage: type (0=TL, 1=BR), r, c, id
    reg [1:0] corner_type [0:127];
    reg [15:0] corner_r [0:127];
    reg [15:0] corner_c [0:127];
    reg [5:0] corner_id [0:127];

    // Sorting variables
    reg [6:0] sort_i, sort_j;
    reg [6:0] min_idx;

    // Validation stack
    reg [5:0] stack [0:63];
    reg [5:0] stack_ptr;

    // Temporary registers
    reg [5:0] current_tl_id;
    reg [5:0] current_br_id;
    reg [5:0] i, j, k;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            cycle_count <= 10'd0;
            result_valid <= 1'b0;
            syntax_error <= 1'b0;
            
            // Initialize corner arrays
            for (i = 0; i < 128; i = i + 1) begin
                corner_type[i] <= 2'd0;
                corner_r[i] <= 16'd0;
                corner_c[i] <= 16'd0;
                corner_id[i] <= 6'd0;
            end
            
            // Initialize match_index
            for (i = 0; i < 64; i = i + 1) begin
                match_index[i] <= 8'd0;
            end
            
            // Initialize stack
            stack_ptr <= 6'd0;
            for (i = 0; i < 64; i = i + 1) begin
                stack[i] <= 6'd0;
            end
            
            // Initialize counters
            sort_i <= 7'd0;
            sort_j <= 7'd0;
            min_idx <= 7'd0;
            current_tl_id <= 6'd0;
            current_br_id <= 6'd0;
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 10'd1;
            
            case (state)
                IDLE: begin
                    result_valid <= 1'b0;
                    syntax_error <= 1'b0;
                    if (start) begin
                        next_state <= LOAD;
                        cycle_count <= 10'd0;
                    end
                end
                
                LOAD: begin
                    // Load TL corners (0-63)
                    for (i = 0; i < 64; i = i + 1) begin
                        corner_type[i] <= 2'd0;
                        corner_r[i] <= tl_r_i[i];
                        corner_c[i] <= tl_c_i[i];
                        corner_id[i] <= i;
                    end
                    
                    // Load BR corners (64-127)
                    for (i = 0; i < 64; i = i + 1) begin
                        corner_type[i + 64] <= 2'd1;
                        corner_r[i + 64] <= br_r_i[i];
                        corner_c[i + 64] <= br_c_i[i];
                        corner_id[i + 64] <= i;
                    end
                    
                    next_state <= SORT;
                    sort_i <= 7'd0;
                    sort_j <= 7'd0;
                    min_idx <= 7'd0;
                end
                
                SORT: begin
                    // Simple selection sort
                    if (sort_i < 127) begin
                        if (sort_j < 128) begin
                            // Find minimum in unsorted portion
                            if (sort_j == 127) begin
                                // Swap if needed
                                if (min_idx != sort_i) begin
                                    // Swap type
                                    corner_type[sort_i] <= corner_type[min_idx];
                                    corner_type[min_idx] <= corner_type[sort_i];
                                    
                                    // Swap r
                                    corner_r[sort_i] <= corner_r[min_idx];
                                    corner_r[min_idx] <= corner_r[sort_i];
                                    
                                    // Swap c
                                    corner_c[sort_i] <= corner_c[min_idx];
                                    corner_c[min_idx] <= corner_c[sort_i];
                                    
                                    // Swap id
                                    corner_id[sort_i] <= corner_id[min_idx];
                                    corner_id[min_idx] <= corner_id[sort_i];
                                end
                                sort_i <= sort_i + 7'd1;
                                sort_j <= sort_i;
                                min_idx <= sort_i;
                            end else begin
                                // Compare corners
                                reg compare_result;
                                compare_result = 1'b0;
                                
                                // Compare by r first
                                if (corner_r[sort_j] < corner_r[min_idx]) begin
                                    compare_result = 1'b1;
                                end else if (corner_r[sort_j] == corner_r[min_idx]) begin
                                    // Then by c
                                    if (corner_c[sort_j] < corner_c[min_idx]) begin
                                        compare_result = 1'b1;
                                    end
                                end
                                
                                if (compare_result) begin
                                    min_idx <= sort_j;
                                end
                                sort_j <= sort_j + 7'd1;
                            end
                        end else begin
                            sort_j <= 7'd0;
                            min_idx <= sort_i;
                        end
                    end else begin
                        next_state <= VALIDATE;
                        stack_ptr <= 6'd0;
                        current_tl_id <= 6'd0;
                        current_br_id <= 6'd0;
                    end
                end
                
                VALIDATE: begin
                    reg [5:0] corner_idx;
                    corner_idx = cycle_count[9:4]; // Use cycle count to index corners
                    
                    if (corner_idx < 128) begin
                        // Check if rectangle is valid
                        if (corner_type[corner_idx] == 2'd0) begin
                            // TL corner - check if valid rectangle
                            reg [5:0] br_id;
                            br_id = corner_id[corner_idx];
                            
                            if (tl_r_i[br_id] > br_r_i[br_id] || tl_c_i[br_id] > br_c_i[br_id]) begin
                                syntax_error <= 1'b1;
                                next_state <= DONE;
                            end else begin
                                // Push to stack
                                if (stack_ptr < 64) begin
                                    stack[stack_ptr] <= corner_id[corner_idx];
                                    stack_ptr <= stack_ptr + 6'd1;
                                end else begin
                                    syntax_error <= 1'b1;
                                    next_state <= DONE;
                                end
                            end
                        end else begin
                            // BR corner
                            if (stack_ptr == 6'd0) begin
                                syntax_error <= 1'b1;
                                next_state <= DONE;
                            end else begin
                                // Pop from stack
                                stack_ptr <= stack_ptr - 6'd1;
                                current_tl_id <= stack[stack_ptr];
                                current_br_id <= corner_id[corner_idx];
                                
                                // Record matching
                                match_index[current_tl_id] <= current_br_id;
                            end
                        end
                    end else begin
                        // Check if stack is empty
                        if (stack_ptr != 6'd0) begin
                            syntax_error <= 1'b1;
                        end
                        next_state <= OUTPUT;
                    end
                end
                
                OUTPUT: begin
                    result_valid <= 1'b1;
                    next_state <= DONE;
                end
                
                DONE: begin
                    result_valid <= 1'b0;
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= IDLE;
                    end
                end
                
                default: next_state <= IDLE;
            endcase
        end
    end

endmodule