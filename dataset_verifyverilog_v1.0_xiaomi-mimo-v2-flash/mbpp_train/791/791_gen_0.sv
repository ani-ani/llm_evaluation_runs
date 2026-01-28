module RemoveNestedTuples (
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
    reg [3:0] index;           // Current input index
    reg [3:0] out_idx;         // Current output index
    reg [7:0] cycle_count;     // Prevent infinite loops
    localparam [7:0] MAX_CYCLES = 8'd200;
    
    // Latched input data
    reg [15:0] latched_input [0:15];
    reg [3:0] latched_len;
    
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            busy <= 1'b0;
            output_len <= 4'd0;
            cycle_count <= 8'd0;
            index <= 4'd0;
            out_idx <= 4'd0;
            // Initialize output_data array
            for (i = 0; i < 16; i = i + 1) begin
                output_data[i] <= 16'd0;
            end
            // Initialize latched_input array
            for (i = 0; i < 16; i = i + 1) begin
                latched_input[i] <= 16'd0;
            end
            latched_len <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    busy <= 1'b0;
                    cycle_count <= 8'd0;
                    index <= 4'd0;
                    out_idx <= 4'd0;
                    output_len <= 4'd0;
                    // Reset output data array
                    for (i = 0; i < 16; i = i + 1) begin
                        output_data[i] <= 16'd0;
                    end
                    // Reset latched input array
                    for (i = 0; i < 16; i = i + 1) begin
                        latched_input[i] <= 16'd0;
                    end
                    latched_len <= 4'd0;
                    
                    if (start) begin
                        busy <= 1'b1;
                        // Latch the input data
                        for (i = 0; i < 16; i = i + 1) begin
                            latched_input[i] <= input_data[i];
                        end
                        latched_len <= input_len;
                        state <= PROCESS;
                    end
                end
                
                PROCESS: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Process current element if within bounds
                    if (index < latched_len) begin
                        // Check upper 8 bits for tuple marker (0xFF)
                        if (latched_input[index][15:8] != 8'hFF) begin
                            // Copy lower 8 bits to output array
                            // Output is 16-bit but only lower 8 bits hold valid data
                            output_data[out_idx] <= {8'd0, latched_input[index][7:0]};
                            out_idx <= out_idx + 4'd1;
                            output_len <= output_len + 4'd1;
                        end
                        index <= index + 4'd1;
                    end else begin
                        // Finished processing all elements
                        state <= FINISH;
                    end
                    
                    // Safety timeout
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    busy <= 1'b0;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule