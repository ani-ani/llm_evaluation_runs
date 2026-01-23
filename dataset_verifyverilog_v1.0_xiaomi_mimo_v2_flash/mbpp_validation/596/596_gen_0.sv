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
    localparam [15:0] HEADER_SIZE = 16'd40;
    localparam [2:0] MAX_ELEMENTS = 3'd8;
    localparam [7:0] MAX_CYCLES = 8'd20;
    
    reg [2:0] state;
    reg [2:0] next_state;
    reg [2:0] count;
    reg [2:0] element_count;
    reg [7:0] cycle_counter;
    
    // State definitions
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] LOAD      = 3'd1;
    localparam [2:0] CALCULATE = 3'd2;
    localparam [2:0] FINISH    = 3'd3;
    
    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = LOAD;
                end else begin
                    next_state = IDLE;
                end
            end
            
            LOAD: begin
                // Wait for all elements to load based on len_i
                if (count >= len_i || (len_i == 3'd0)) begin
                    next_state = CALCULATE;
                end else begin
                    next_state = LOAD;
                end
            end
            
            CALCULATE: begin
                next_state = FINISH;
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end
    
    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            size_o <= 16'd0;
            count <= 3'd0;
            element_count <= 3'd0;
            cycle_counter <= 8'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_counter <= 8'd0;
                    if (start) begin
                        count <= 3'd0;
                        element_count <= 3'd0;
                    end
                end
                
                LOAD: begin
                    cycle_counter <= cycle_counter + 8'd1;
                    
                    if (data_valid) begin
                        count <= count + 3'd1;
                        // Capture element count when valid
                        if (count < len_i) begin
                            element_count <= element_count + 3'd1;
                        end
                    end
                    
                    // Safety timeout
                    if (cycle_counter >= MAX_CYCLES) begin
                        state <= CALCULATE;
                    end
                end
                
                CALCULATE: begin
                    // Size = 40 + number_of_elements
                    size_o <= HEADER_SIZE + element_count;
                end
                
                FINISH: begin
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule