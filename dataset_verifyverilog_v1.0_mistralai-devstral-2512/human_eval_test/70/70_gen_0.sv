module strange_sort(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire arr_valid,
    input wire [3:0] len,
    input wire [15:0] arr_in,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] SORT = 3'd1;
    localparam [2:0] SELECT = 3'd2;
    localparam [2:0] OUTPUT = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    reg [2:0] state, next_state;
    reg [15:0] sorted_arr;
    reg [15:0] removed_mask;
    reg [3:0] cycle_count;
    reg [3:0] current_index;
    reg [7:0] current_element;
    reg [7:0] output_element;
    reg [3:0] output_index;
    reg [3:0] max_cycles;

    // Bubble sort implementation
    integer i, j;
    reg [7:0] temp;
    reg [7:0] arr [0:15];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            sorted_arr <= 16'd0;
            removed_mask <= 16'd0;
            cycle_count <= 4'd0;
            current_index <= 4'd0;
            current_element <= 8'd0;
            output_element <= 8'd0;
            output_index <= 4'd0;
            max_cycles <= 4'd0;
            done <= 1'b0;
            result <= 16'd0;
            
            // Initialize array
            for (i = 0; i < 16; i = i + 1) begin
                arr[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start && arr_valid) begin
                        // Extract input array
                        for (i = 0; i < 16; i = i + 1) begin
                            if (i < len) begin
                                arr[i] <= arr_in[(i*8)+7:i*8];
                            end else begin
                                arr[i] <= 8'd0;
                            end
                        end
                        next_state <= SORT;
                    end
                end
                
                SORT: begin
                    // Bubble sort
                    for (i = 0; i < 15; i = i + 1) begin
                        for (j = 0; j < 15 - i; j = j + 1) begin
                            if (arr[j] > arr[j+1]) begin
                                temp <= arr[j];
                                arr[j] <= arr[j+1];
                                arr[j+1] <= temp;
                            end
                        end
                    end
                    
                    // Store sorted array
                    for (i = 0; i < 16; i = i + 1) begin
                        sorted_arr[(i*8)+7:i*8] <= arr[i];
                    end
                    
                    // Initialize for selection
                    removed_mask <= 16'd0;
                    cycle_count <= 4'd0;
                    current_index <= 4'd0;
                    output_index <= 4'd0;
                    max_cycles <= len;
                    next_state <= SELECT;
                end
                
                SELECT: begin
                    if (cycle_count < max_cycles) begin
                        if (cycle_count[0] == 1'b0) begin
                            // Even cycle: find min not removed
                            for (i = 0; i < 16; i = i + 1) begin
                                if (!removed_mask[i] && (i < len)) begin
                                    current_element <= sorted_arr[(i*8)+7:i*8];
                                    current_index <= i;
                                    break;
                                end
                            end
                        end else begin
                            // Odd cycle: find max not removed
                            for (i = 15; i >= 0; i = i - 1) begin
                                if (!removed_mask[i] && (i < len)) begin
                                    current_element <= sorted_arr[(i*8)+7:i*8];
                                    current_index <= i;
                                    break;
                                end
                            end
                        end
                        
                        // Mark as removed
                        removed_mask[current_index] <= 1'b1;
                        output_element <= current_element;
                        
                        // Store in result
                        if (output_index == 4'd0) begin
                            result[7:0] <= output_element;
                        end else if (output_index == 4'd1) begin
                            result[15:8] <= output_element;
                        end
                        
                        output_index <= output_index + 4'd1;
                        cycle_count <= cycle_count + 4'd1;
                        
                        if (cycle_count == max_cycles) begin
                            next_state <= OUTPUT;
                        end
                    end else begin
                        next_state <= OUTPUT;
                    end
                end
                
                OUTPUT: begin
                    done <= 1'b1;
                    next_state <= DONE_STATE;
                end
                
                DONE_STATE: begin
                    done <= 1'b0;
                    next_state <= IDLE;
                end
                
                default: next_state <= IDLE;
            endcase
        end
    end

endmodule