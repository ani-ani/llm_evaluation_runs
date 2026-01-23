module is_sorted_checker (
    input clk,
    input rst_n,
    input start,
    input [7:0] data_in,
    input [2:0] index,
    input data_valid,
    output reg is_sorted,
    output reg done,
    output reg [2:0] error_index
);

    // Internal array to store 8 elements
    reg [7:0] list [0:7];
    
    // State encoding
    localparam IDLE = 2'b00;
    localparam LOAD_DATA = 2'b01;
    localparam CHECKING = 2'b10;
    localparam DONE_STATE = 2'b11;
    
    reg [1:0] current_state;
    reg [2:0] load_count;
    reg [2:0] check_index;
    reg data_loaded;
    
    // State transition and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            is_sorted <= 1'b0;
            done <= 1'b0;
            error_index <= 3'b0;
            load_count <= 3'b0;
            check_index <= 3'b0;
            data_loaded <= 1'b0;
        end else begin
            case (current_state)
                IDLE: begin
                    done <= 1'b0;
                    error_index <= 3'b0;
                    if (start) begin
                        current_state <= LOAD_DATA;
                        load_count <= 3'b0;
                        data_loaded <= 1'b0;
                    end
                end
                
                LOAD_DATA: begin
                    if (data_valid) begin
                        list[index] <= data_in;
                        load_count <= load_count + 1'b1;
                    end
                    // Check if we have loaded 8 elements
                    if (load_count == 3'd7 && (data_valid || load_count == 3'd7)) begin
                        // Wait for the current cycle to complete if data_valid was high
                        if (data_valid || load_count == 3'd7) begin
                            current_state <= CHECKING;
                            check_index <= 3'b0;
                            is_sorted <= 1'b1; // Assume sorted until proven otherwise
                        end
                    end
                    // Also transition if start is deasserted and we already have data
                    // But spec says start initiates checking after load
                    // We need to check if we have all 8 elements loaded
                    // The count logic needs to handle the case where data_valid comes in
                end
                
                CHECKING: begin
                    // Compare list[check_index] and list[check_index + 1]
                    if (list[check_index] > list[check_index + 1]) begin
                        is_sorted <= 1'b0;
                        error_index <= check_index;
                        current_state <= DONE_STATE;
                        done <= 1'b1;
                    end else begin
                        if (check_index == 3'd6) begin
                            // Finished all comparisons
                            is_sorted <= 1'b1;
                            error_index <= 3'b0;
                            current_state <= DONE_STATE;
                            done <= 1'b1;
                        end else begin
                            check_index <= check_index + 1'b1;
                        end
                    end
                end
                
                DONE_STATE: begin
                    // Wait here until reset or new start
                    // To allow start to reset the cycle, we need to go back to IDLE when start is low
                    // But usually, start goes low after one cycle. 
                    // We stay in DONE until reset or a new sequence initiated by IDLE transition.
                    // Spec implies behavior for a sequence. 
                    // Let's return to IDLE when start is 0 to be ready for next trigger.
                    if (!start) begin
                        current_state <= IDLE;
                        done <= 1'b0;
                    end
                end
            endcase
        end
    end

endmodule