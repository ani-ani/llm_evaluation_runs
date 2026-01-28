module tuple_filter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] input_data [0:15],
    input wire [3:0] input_len,
    output reg [15:0] output_data [0:15],
    output reg [3:0] output_len,
    output reg done,
    output reg busy
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESS = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state;
    reg [3:0] current_index;
    reg [3:0] output_index;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Initialize all registers
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_index <= 4'd0;
            output_index <= 4'd0;
            output_len <= 4'd0;
            done <= 1'b0;
            busy <= 1'b0;
            cycle_count <= 8'd0;
            for (i = 0; i < 16; i = i + 1) begin
                output_data[i] <= 16'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    busy <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= PROCESS;
                        busy <= 1'b1;
                        current_index <= 4'd0;
                        output_index <= 4'd0;
                        output_len <= 4'd0;
                    end
                end
                
                PROCESS: begin
                    busy <= 1'b1;
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Process current element
                    if (current_index < input_len) begin
                        if (input_data[current_index][15:8] == 8'h00) begin
                            // Valid integer - copy lower 8 bits
                            output_data[output_index] <= {8'd0, input_data[current_index][7:0]};
                            output_index <= output_index + 4'd1;
                        end
                        current_index <= current_index + 4'd1;
                    end
                    
                    // Check if processing is complete
                    if (current_index >= input_len || cycle_count >= MAX_CYCLES) begin
                        output_len <= output_index;
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    busy <= 1'b0;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                    busy <= 1'b0;
                end
            endcase
        end
    end
    
endmodule