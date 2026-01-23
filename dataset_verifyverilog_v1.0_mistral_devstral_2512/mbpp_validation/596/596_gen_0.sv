module tuple_size_calculator (
    input wire clk,              // Clock signal
    input wire rst_n,            // Active-low synchronous reset
    input wire start,            // Start pulse (1 cycle)
    input wire [7:0] data_i,     // Input data byte
    input wire [2:0] len_i,      // Number of elements (0-7, representing 1-8)
    input wire data_valid,       // Data valid signal for loading
    output reg [15:0] size_o,    // Total size in bytes
    output reg done              // Computation complete signal
);

    // Fixed overhead: 40 bytes (simulates Python object header)
    // Per-element storage: 1 byte each (simulates data payload)
    // Total size = 40 + number_of_elements
    
    reg [2:0] state;
    reg [2:0] count;
    reg [7:0] data_buffer [0:7]; // 8-element buffer
    reg [2:0] element_count;     // Number of valid elements
    
    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] CALCULATE = 3'd2;
    localparam [2:0] FINISH = 3'd3;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            size_o <= 16'd0;
            count <= 3'd0;
            element_count <= 3'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= LOAD;
                        count <= 3'd0;
                        element_count <= len_i;
                    end
                end
                
                LOAD: begin
                    if (data_valid && count < len_i) begin
                        data_buffer[count] <= data_i;
                        count <= count + 3'd1;
                    end else if (count >= len_i || len_i == 3'd0) begin
                        state <= CALCULATE;
                    end
                end
                
                CALCULATE: begin
                    // Size = 40 (header) + number_of_elements
                    size_o <= 16'd40 + element_count;
                    state <= FINISH;
                end
                
                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule