module odd_filter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr_in [0:7],
    output reg [7:0] arr_out [0:7],
    output reg done,
    output reg [3:0] valid_count
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] PROCESS = 3'd1;
    localparam [2:0] DONE    = 3'd2;

    reg [2:0] state;
    reg [2:0] next_state;

    // Processing variables
    reg [2:0] index;
    reg [2:0] out_index;
    reg [7:0] current_element;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            valid_count <= 4'd0;
            index <= 3'd0;
            out_index <= 3'd0;
            current_element <= 8'd0;
            
            // Initialize output array
            integer i;
            for (i = 0; i < 8; i = i + 1) begin
                arr_out[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        next_state <= PROCESS;
                        index <= 3'd0;
                        out_index <= 3'd0;
                        valid_count <= 4'd0;
                    end else begin
                        next_state <= IDLE;
                    end
                end
                
                PROCESS: begin
                    // Process current element
                    current_element <= arr_in[index];
                    
                    // Check if element is even (LSB = 0)
                    if (current_element[0] == 1'b0) begin
                        arr_out[out_index] <= current_element;
                        out_index <= out_index + 3'd1;
                        valid_count <= valid_count + 4'd1;
                    end
                    
                    // Move to next element
                    if (index == 3'd7) begin
                        next_state <= DONE;
                    end else begin
                        index <= index + 3'd1;
                        next_state <= PROCESS;
                    end
                end
                
                DONE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end
                
                default: next_state <= IDLE;
            endcase
        end
    end
endmodule