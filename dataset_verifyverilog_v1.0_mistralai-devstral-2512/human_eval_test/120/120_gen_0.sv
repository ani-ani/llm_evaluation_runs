module k_max_sorter(
    input wire clk,
    input wire rst_n,
    input wire start,
    output reg done,
    input wire signed [8:0] arr [0:15],
    input wire [4:0] k,
    input wire [15:0] arr_valid,
    output reg signed [8:0] result [0:15],
    output reg [15:0] result_valid
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] SELECT = 3'd1;
    localparam [2:0] SORT = 3'd2;
    localparam [2:0] OUTPUT = 3'd3;

    // Internal registers
    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    // Storage for selected max values
    reg signed [8:0] selected [0:15];
    reg [15:0] selected_valid;

    // Selection phase registers
    reg [3:0] select_index;
    reg [3:0] select_count;
    reg signed [8:0] current_max;
    reg [3:0] current_max_index;

    // Sort phase registers
    reg [3:0] sort_pass;
    reg [3:0] sort_i;
    reg [3:0] sort_j;
    reg signed [8:0] temp_val;

    // Output phase registers
    reg [3:0] output_index;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            cycle_count <= 8'd0;
            
            // Clear selected array
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                selected[i] <= 9'd0;
            end
            selected_valid <= 16'd0;
            
            // Clear result
            for (i = 0; i < 16; i = i + 1) begin
                result[i] <= 9'd0;
            end
            result_valid <= 16'd0;
            
            // Clear selection registers
            select_index <= 4'd0;
            select_count <= 4'd0;
            current_max <= 9'd0;
            current_max_index <= 4'd0;
            
            // Clear sort registers
            sort_pass <= 4'd0;
            sort_i <= 4'd0;
            sort_j <= 4'd0;
            
            // Clear output registers
            output_index <= 4'd0;
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 8'd1;
        end
    end

    // State machine logic
    always @(*) begin
        next_state = state;
        done = 1'b0;
        
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = SELECT;
                    cycle_count = 8'd0;
                    
                    // Initialize selection
                    select_count = 4'd0;
                    select_index = 4'd0;
                    
                    // Clear selected array
                    integer i;
                    for (i = 0; i < 16; i = i + 1) begin
                        selected[i] = 9'd0;
                    end
                    selected_valid = 16'd0;
                end
            end
            
            SELECT: begin
                if (select_count < k && cycle_count < MAX_CYCLES) begin
                    // Find maximum in remaining array
                    if (select_index == 4'd0) begin
                        // Initialize search
                        current_max = 9'sd512; // Start with minimum possible value
                        current_max_index = 4'd0;
                    end
                    
                    // Check if current element is valid and larger than current max
                    if (arr_valid[select_index] && 
                        (arr[select_index] > current_max || 
                         (arr[select_index] == current_max && 
                          !selected_valid[select_index]))) begin
                        current_max = arr[select_index];
                        current_max_index = select_index;
                    end
                    
                    // Move to next index
                    if (select_index == 4'd15) begin
                        // Found max for this iteration
                        selected[select_count] = current_max;
                        selected_valid[select_count] = 1'b1;
                        select_count = select_count + 4'd1;
                        select_index = 4'd0;
                        
                        // Check if we've found all k values
                        if (select_count == k) begin
                            next_state = SORT;
                            sort_pass = 4'd0;
                            sort_i = 4'd0;
                            sort_j = 4'd0;
                        end
                    end else begin
                        select_index = select_index + 4'd1;
                    end
                end else if (cycle_count >= MAX_CYCLES) begin
                    next_state = IDLE;
                end
            end
            
            SORT: begin
                if (cycle_count < MAX_CYCLES) begin
                    // Bubble sort implementation
                    if (sort_pass < k) begin
                        if (sort_i < k - sort_pass - 4'd1) begin
                            // Compare and swap
                            if (selected[sort_i] > selected[sort_i + 4'd1]) begin
                                temp_val = selected[sort_i];
                                selected[sort_i] = selected[sort_i + 4'd1];
                                selected[sort_i + 4'd1] = temp_val;
                            end
                            
                            if (sort_i == k - sort_pass - 4'd2) begin
                                sort_i = 4'd0;
                                sort_pass = sort_pass + 4'd1;
                            end else begin
                                sort_i = sort_i + 4'd1;
                            end
                        end else begin
                            sort_i = 4'd0;
                            sort_pass = sort_pass + 4'd1;
                        end
                    end else begin
                        // Sorting complete
                        next_state = OUTPUT;
                        output_index = 4'd0;
                    end
                end else begin
                    next_state = IDLE;
                end
            end
            
            OUTPUT: begin
                if (output_index < 16 && cycle_count < MAX_CYCLES) begin
                    if (output_index < k) begin
                        result[output_index] = selected[output_index];
                        result_valid[output_index] = 1'b1;
                    end else begin
                        result[output_index] = 9'd0;
                        result_valid[output_index] = 1'b0;
                    end
                    
                    if (output_index == 4'd15) begin
                        done = 1'b1;
                        next_state = IDLE;
                    end else begin
                        output_index = output_index + 4'd1;
                    end
                end else if (cycle_count >= MAX_CYCLES) begin
                    next_state = IDLE;
                end
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule