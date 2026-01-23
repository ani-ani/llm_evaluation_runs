module combination_generator(
    input wire clk,
    input wire rst_n,
    input wire [7:0] arr [0:5],
    input wire [5:0] valid_mask,
    output reg [15:0] out_data,
    output reg out_valid,
    output reg [7:0] out_element,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] GENERATE = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state;
    reg [5:0] mask_counter;  // 6-bit counter for all combinations
    reg [2:0] element_counter;  // 3-bit counter for elements in current combination
    reg [5:0] total_combinations;  // Total number of valid combinations
    reg [5:0] current_combination;  // Current combination index
    reg [2:0] current_size;  // Number of elements in current combination
    reg [5:0] valid_elements;  // Number of valid elements in input
    
    // Calculate number of valid elements
    always @(*) begin
        valid_elements = 0;
        for (integer i = 0; i < 6; i = i + 1) begin
            if (valid_mask[i]) begin
                valid_elements = valid_elements + 1'b1;
            end
        end
    end
    
    // Calculate total combinations (2^valid_elements)
    always @(*) begin
        total_combinations = 1;
        for (integer i = 0; i < valid_elements; i = i + 1) begin
            total_combinations = total_combinations << 1;
        end
    end
    
    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            mask_counter <= 6'd0;
            element_counter <= 3'd0;
            total_combinations <= 6'd0;
            current_combination <= 6'd0;
            current_size <= 3'd0;
            out_data <= 16'd0;
            out_valid <= 1'b0;
            out_element <= 8'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    out_valid <= 1'b0;
                    mask_counter <= 6'd0;
                    element_counter <= 3'd0;
                    current_combination <= 6'd0;
                    current_size <= 3'd0;
                    state <= GENERATE;
                end
                
                GENERATE: begin
                    // Calculate current combination size
                    current_size = 0;
                    for (integer i = 0; i < 6; i = i + 1) begin
                        if (valid_mask[i] && mask_counter[i]) begin
                            current_size = current_size + 1'b1;
                        end
                    end
                    
                    // Output current element
                    if (element_counter < current_size) begin
                        integer i;
                        reg found;
                        found = 1'b0;
                        for (i = 0; i < 6; i = i + 1) begin
                            if (!found && valid_mask[i] && mask_counter[i]) begin
                                if (element_counter == 0) begin
                                    found = 1'b1;
                                    out_element <= arr[i];
                                    out_valid <= 1'b1;
                                    out_data <= {total_combinations, current_combination, current_size};
                                end else begin
                                    element_counter = element_counter - 1'b1;
                                end
                            end
                        end
                        element_counter = element_counter + 1'b1;
                    end else begin
                        // Move to next combination
                        element_counter <= 3'd0;
                        mask_counter <= mask_counter + 6'd1;
                        current_combination <= current_combination + 6'd1;
                        
                        // Check if all combinations are done
                        if (mask_counter == (1 << valid_elements)) begin
                            state <= FINISH;
                        end
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    out_valid <= 1'b0;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
    
    // Default assignments for outputs
    assign out_data = {total_combinations, current_combination, current_size};

endmodule