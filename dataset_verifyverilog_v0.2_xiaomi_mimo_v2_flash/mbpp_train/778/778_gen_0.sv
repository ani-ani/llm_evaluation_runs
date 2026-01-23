module pack_duplicates (
    input clk,
    input rst_n,
    input start,
    input [3:0] length,
    input [15:0] data_in [0:15],
    output reg [3:0] group_starts [0:15],
    output reg [3:0] group_lengths [0:15],
    output reg [3:0] num_groups,
    output reg done
);

    // State definition
    localparam IDLE = 2'b00;
    localparam PROCESSING = 2'b01;
    localparam DONE = 2'b10;

    reg [1:0] current_state;
    reg [3:0] index;
    reg [15:0] prev_data;
    reg [3:0] current_group_index;
    reg processing_started;

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset logic
            current_state <= IDLE;
            index <= 4'b0;
            num_groups <= 4'b0;
            done <= 1'b0;
            prev_data <= 16'b0;
            current_group_index <= 4'b0;
            processing_started <= 1'b0;
            
            // Reset outputs arrays to 0
            for (i = 0; i < 16; i = i + 1) begin
                group_starts[i] <= 4'b0;
                group_lengths[i] <= 4'b0;
            end
        end else begin
            case (current_state)
                IDLE: begin
                    done <= 1'b0;
                    if (start && !processing_started) begin
                        // Initialize processing
                        if (length > 0) begin
                            current_state <= PROCESSING;
                            index <= 4'b0;
                            current_group_index <= 4'b0;
                            
                            // Start first group
                            group_starts[0] <= 4'b0;
                            group_lengths[0] <= 4'b0; // Will increment in PROCESSING
                            
                            // Capture first element
                            prev_data <= data_in[0];
                            
                            // Handle case where length is 1 immediately
                            if (length == 1) begin
                                group_lengths[0] <= 4'd1;
                                num_groups <= 4'd1;
                                done <= 1'b1;
                                current_state <= DONE;
                                processing_started <= 1'b1;
                            end else begin
                                processing_started <= 1'b1;
                            end
                        end else begin
                            // Length 0 case
                            num_groups <= 4'b0;
                            done <= 1'b1;
                            current_state <= DONE;
                            processing_started <= 1'b1;
                        end
                    end
                end

                PROCESSING: begin
                    if (processing_started) begin
                        if (index < length) begin
                            // Update length for current group
                            group_lengths[current_group_index] <= group_lengths[current_group_index] + 1'b1;
                            
                            // Check next element for group boundary (unless we are at the last element)
                            if (index < length - 1) begin
                                if (data_in[index + 1] != prev_data) begin
                                    // Boundary detected: move to next group
                                    current_group_index <= current_group_index + 1'b1;
                                    group_starts[current_group_index + 1'b1] <= index + 1'b1;
                                    group_lengths[current_group_index + 1'b1] <= 4'b0; // Reset next group length
                                    prev_data <= data_in[index + 1]; // Update prev for next group start
                                end else begin
                                    // Still in same group, just update prev_data for comparison continuity (redundant but safe)
                                    prev_data <= data_in[index + 1];
                                end
                            end
                            
                            index <= index + 1'b1;
                        end else begin
                            // Processing finished (handled all 'length' elements)
                            num_groups <= current_group_index + 1'b1;
                            done <= 1'b1;
                            current_state <= DONE;
                            processing_started <= 1'b0; // Reset for next start
                        end
                    end
                end

                DONE: begin
                    // Stay here until reset or start signal goes low then high again
                    // To allow restart, we check if start is low first
                    if (!start) begin
                        done <= 1'b0;
                        processing_started <= 1'b0;
                        current_state <= IDLE;
                    end
                end

                default: current_state <= IDLE;
            endcase
        end
    end

endmodule