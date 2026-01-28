module frequency_counter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr [0:7],
    input wire [3:0] len,
    output reg done,
    output reg [7:0] result_keys [0:7],
    output reg [7:0] result_counts [0:7],
    output reg [3:0] valid_pairs
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COUNT = 3'd1;
    localparam [2:0] SORT = 3'd2;
    localparam [2:0] OUTPUT = 3'd3;
    
    reg [2:0] state, next_state;
    
    // Internal registers
    reg [7:0] keys [0:7];
    reg [7:0] counts [0:7];
    reg [3:0] unique_count;
    reg [7:0] current_value;
    reg [7:0] temp_key;
    reg [7:0] temp_count;
    reg [3:0] i, j, k;
    reg found;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd190;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            valid_pairs <= 4'd0;
            
            for (i = 0; i < 8; i = i + 1) begin
                result_keys[i] <= 8'd0;
                result_counts[i] <= 8'd0;
                keys[i] <= 8'd0;
                counts[i] <= 8'd0;
            end
            
            unique_count <= 4'd0;
            current_value <= 8'd0;
            temp_key <= 8'd0;
            temp_count <= 8'd0;
            i <= 4'd0;
            j <= 4'd0;
            k <= 4'd0;
            found <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
        end
    end

    // State machine logic
    always @(*) begin
        next_state = state;
        done = 1'b0;
        
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = COUNT;
                    // Initialize counters
                    unique_count = 4'd0;
                    i = 4'd0;
                    j = 4'd0;
                    k = 4'd0;
                    cycle_count = 8'd0;
                    
                    // Clear internal arrays
                    for (i = 0; i < 8; i = i + 1) begin
                        keys[i] = 8'd0;
                        counts[i] = 8'd0;
                    end
                end
            end
            
            COUNT: begin
                cycle_count = cycle_count + 8'd1;
                
                if (i < len) begin
                    current_value = arr[i];
                    
                    // Check if value already exists in keys
                    found = 1'b0;
                    for (j = 0; j < unique_count; j = j + 1) begin
                        if (keys[j] == current_value) begin
                            found = 1'b1;
                            counts[j] = counts[j] + 8'd1;
                        end
                    end
                    
                    // If not found and we have space, add it
                    if (!found && unique_count < 8) begin
                        keys[unique_count] = current_value;
                        counts[unique_count] = 8'd1;
                        unique_count = unique_count + 4'd1;
                    end
                    
                    i = i + 4'd1;
                end else begin
                    next_state = SORT;
                    i = 4'd0;
                    j = 4'd0;
                end
                
                // Safety: prevent infinite loops
                if (cycle_count >= MAX_CYCLES) begin
                    next_state = OUTPUT;
                end
            end
            
            SORT: begin
                cycle_count = cycle_count + 8'd1;
                
                // Bubble sort implementation
                if (i < unique_count - 4'd1) begin
                    if (keys[i] > keys[i + 4'd1]) begin
                        // Swap keys
                        temp_key = keys[i];
                        keys[i] = keys[i + 4'd1];
                        keys[i + 4'd1] = temp_key;
                        
                        // Swap counts
                        temp_count = counts[i];
                        counts[i] = counts[i + 4'd1];
                        counts[i + 4'd1] = temp_count;
                    end
                    
                    i = i + 4'd1;
                end else begin
                    if (j < unique_count - 4'd1) begin
                        i = 4'd0;
                        j = j + 4'd1;
                    end else begin
                        next_state = OUTPUT;
                    end
                end
                
                // Safety: prevent infinite loops
                if (cycle_count >= MAX_CYCLES) begin
                    next_state = OUTPUT;
                end
            end
            
            OUTPUT: begin
                // Copy results to output
                valid_pairs = unique_count;
                for (k = 0; k < 8; k = k + 1) begin
                    result_keys[k] = keys[k];
                    result_counts[k] = counts[k];
                end
                
                done = 1'b1;
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

endmodule