module find_largest_d(
    input clk,
    input rst_n,
    input start,
    input [23:0] data_in,
    input [2:0] index,
    input write_en,
    output reg [23:0] result,
    output reg valid,
    output reg done
);

    // Internal storage for 8 numbers
    reg signed [23:0] data[0:7];
    
    // State definition
    localparam IDLE = 3'b000;
    localparam WRITE_MODE = 3'b001;
    localparam COMPUTE = 3'b010;
    localparam DONE = 3'b011;
    
    // Loop counter registers
    reg [2:0] i, j, k, l;
    reg signed [23:0] current_max;
    reg found_solution;
    
    // State register
    reg [2:0] state;
    
    // Control flags
    reg searching;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 24'sd0;
            valid <= 1'b0;
            done <= 1'b0;
            i <= 3'd0;
            j <= 3'd0;
            k <= 3'd0;
            l <= 3'd0;
            current_max <= 24'sh800000; // Minimum value for 24-bit signed
            found_solution <= 1'b0;
            searching <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    if (write_en) begin
                        data[index] <= data_in;
                        state <= WRITE_MODE;
                    end else if (start) begin
                        // Reset loop counters and max value
                        i <= 3'd0;
                        j <= 3'd0;
                        k <= 3'd0;
                        l <= 3'd0;
                        current_max <= 24'sh800000;
                        found_solution <= 1'b0;
                        state <= COMPUTE;
                    end
                end
                
                WRITE_MODE: begin
                    if (write_en) begin
                        data[index] <= data_in;
                    end else if (start) begin
                        // Start computation after writing
                        i <= 3'd0;
                        j <= 3'd0;
                        k <= 3'd0;
                        l <= 3'd0;
                        current_max <= 24'sh800000;
                        found_solution <= 1'b0;
                        state <= COMPUTE;
                    end else if (!write_en) begin
                        state <= IDLE;
                    end
                end
                
                COMPUTE: begin
                    // Check distinctness and sum equality
                    // i, j, k, l must be distinct
                    if ((i != j) && (i != k) && (i != l) && 
                        (j != k) && (j != l) && (k != l)) begin
                        
                        // Check if data[i] + data[j] + data[k] == data[l]
                        if (data[i] + data[j] + data[k] == data[l]) begin
                            if (data[l] > current_max) begin
                                current_max <= data[l];
                                found_solution <= 1'b1;
                            end
                        end
                    end
                    
                    // Increment counters (nested loop logic)
                    // Order: l loops fastest, then k, then j, then i
                    if (l < 3'd7) begin
                        l <= l + 1'b1;
                    end else begin
                        l <= 3'd0;
                        if (k < 3'd7) begin
                            k <= k + 1'b1;
                        end else begin
                            k <= 3'd0;
                            if (j < 3'd7) begin
                                j <= j + 1'b1;
                            end else begin
                                j <= 3'd0;
                                if (i < 3'd7) begin
                                    i <= i + 1'b1;
                                end else begin
                                    // All iterations complete
                                    if (found_solution) begin
                                        result <= current_max;
                                        valid <= 1'b1;
                                    end else begin
                                        result <= 24'sd0;
                                        valid <= 1'b0;
                                    end
                                    done <= 1'b1;
                                    state <= DONE;
                                end
                            end
                        end
                    end
                end
                
                DONE: begin
                    // Wait for new start signal
                    if (start) begin
                        done <= 1'b0;
                        valid <= 1'b0;
                        i <= 3'd0;
                        j <= 3'd0;
                        k <= 3'd0;
                        l <= 3'd0;
                        current_max <= 24'sh800000;
                        found_solution <= 1'b0;
                        state <= COMPUTE;
                    end else if (write_en) begin
                        data[index] <= data_in;
                        state <= WRITE_MODE;
                        done <= 1'b0;
                        valid <= 1'b0;
                    end else begin
                        state <= IDLE;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule