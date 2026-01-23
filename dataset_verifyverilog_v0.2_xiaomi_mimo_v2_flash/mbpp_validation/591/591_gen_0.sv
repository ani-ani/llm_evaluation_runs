module swap_list(
    input clk,
    input rst_n,
    input start,
    input [4:0][7:0] data_in,
    output reg [4:0][7:0] data_out,
    output reg done
);

    // State definitions
    localparam IDLE = 2'b00;
    localparam SWAP = 2'b01;
    localparam DONE = 2'b10;

    reg [1:0] current_state, next_state;
    
    // Temporary registers for swap
    reg [7:0] temp_first;
    reg [7:0] temp_last;

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        case (current_state)
            IDLE: begin
                if (start)
                    next_state = SWAP;
                else
                    next_state = IDLE;
            end
            SWAP: begin
                next_state = DONE;
            end
            DONE: begin
                if (start)
                    next_state = DONE;
                else
                    next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_out <= 5'b0;
            done <= 1'b0;
            temp_first <= 8'b0;
            temp_last <= 8'b0;
        end else begin
            case (next_state)
                IDLE: begin
                    data_out <= 5'b0;
                    done <= 1'b0;
                end
                SWAP: begin
                    // Store original first and last elements
                    temp_first <= data_in[0];
                    temp_last <= data_in[4];
                    
                    // Perform swap: first gets last, last gets first
                    data_out[0] <= data_in[4];
                    data_out[4] <= data_in[0];
                    
                    // Copy middle elements unchanged
                    data_out[1] <= data_in[1];
                    data_out[2] <= data_in[2];
                    data_out[3] <= data_in[3];
                    
                    done <= 1'b0;
                end
                DONE: begin
                    // Keep swapped values and assert done
                    data_out[0] <= temp_last;
                    data_out[4] <= temp_first;
                    data_out[1] <= data_out[1];
                    data_out[2] <= data_out[2];
                    data_out[3] <= data_out[3];
                    
                    done <= 1'b1;
                end
                default: begin
                    data_out <= 5'b0;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule}