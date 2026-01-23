module combinational_generator(
    input wire clk,
    input wire rst_n,
    input wire [7:0] arr [0:5],
    input wire [5:0] valid_mask,
    output reg [15:0] out_data,
    output reg out_valid,
    output reg [7:0] out_element,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE         = 3'd0;
    localparam [2:0] PROCESS_MASK = 3'd1;
    localparam [2:0] OUTPUT_ELEMENT = 3'd2;
    localparam [2:0] NEXT_MASK    = 3'd3;
    localparam [2:0] FINISH       = 3'd4;

    // Registers
    reg [2:0] state;
    reg [5:0] mask_counter;      // 0 to 63 for all combinations
    reg [2:0] bit_position;      // 0 to 5 for scanning bits
    reg [2:0] element_count;     // Count of elements in current combination
    reg [2:0] valid_count;       // Number of valid elements in current combination
    reg [5:0] current_mask;      // Current mask being processed
    reg [2:0] output_index;      // Track position in output sequence
    reg [5:0] total_combinations; // 2^(number of valid bits)
    reg [2:0] num_valid_bits;    // Count of valid bits in valid_mask

    // Helper: count bits in valid_mask
    integer i;
    always @(*) begin
        num_valid_bits = 3'd0;
        for (i = 0; i < 6; i = i + 1) begin
            if (valid_mask[i]) begin
                num_valid_bits = num_valid_bits + 3'd1;
            end
        end
        total_combinations = (num_valid_bits == 3'd0) ? 6'd1 : (6'd1 << num_valid_bits);
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            mask_counter <= 6'd0;
            bit_position <= 3'd0;
            element_count <= 3'd0;
            valid_count <= 3'd0;
            current_mask <= 6'd0;
            output_index <= 3'd0;
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
                    bit_position <= 3'd0;
                    element_count <= 3'd0;
                    valid_count <= 3'd0;
                    current_mask <= 6'd0;
                    output_index <= 3'd0;
                    state <= PROCESS_MASK;
                end

                PROCESS_MASK: begin
                    // Calculate element count for current mask
                    element_count <= 3'd0;
                    valid_count <= 3'd0;
                    for (i = 0; i < 6; i = i + 1) begin
                        if (current_mask[i] && valid_mask[i]) begin
                            element_count <= element_count + 3'd1;
                        end
                        if (valid_mask[i]) begin
                            valid_count <= valid_count + 3'd1;
                        end
                    end
                    
                    // Build output data header
                    out_data[15:12] <= (num_valid_bits == 3'd0) ? 4'd1 : (4'd1 << num_valid_bits);
                    out_data[11:8] <= mask_counter[3:0];
                    out_data[7:0] <= {5'd0, element_count};
                    
                    bit_position <= 3'd0;
                    
                    // Check if mask has any elements to output
                    if (element_count == 3'd0) begin
                        // Empty combination, skip to next
                        state <= NEXT_MASK;
                        out_valid <= 1'b0;
                    end else begin
                        state <= OUTPUT_ELEMENT;
                        out_valid <= 1'b0;
                    end
                end

                OUTPUT_ELEMENT: begin
                    // Find next valid element in current mask
                    if (bit_position < 3'd6 && current_mask[bit_position] && valid_mask[bit_position]) begin
                        out_element <= arr[bit_position];
                        out_valid <= 1'b1;
                        bit_position <= bit_position + 3'd1;
                        state <= OUTPUT_ELEMENT;
                    end else if (bit_position < 3'd6) begin
                        bit_position <= bit_position + 3'd1;
                        state <= OUTPUT_ELEMENT;
                    end else begin
                        // Done outputting all elements for this mask
                        out_valid <= 1'b0;
                        state <= NEXT_MASK;
                    end
                end

                NEXT_MASK: begin
                    if (mask_counter < (total_combinations - 6'd1)) begin
                        mask_counter <= mask_counter + 6'd1;
                        current_mask <= mask_counter + 6'd1;
                        state <= PROCESS_MASK;
                        out_valid <= 1'b0;
                    end else begin
                        state <= FINISH;
                        out_valid <= 1'b0;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    out_valid <= 1'b0;
                    // Stay in FINISH state
                end

                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                    out_valid <= 1'b0;
                end
            endcase
        end
    end

endmodule