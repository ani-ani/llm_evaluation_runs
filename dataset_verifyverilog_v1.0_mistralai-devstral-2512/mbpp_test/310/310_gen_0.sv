module StringToTupleConverter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] input_string [0:15],
    input wire [3:0] input_length,
    output reg [7:0] output_tuple [0:15],
    output reg [3:0] output_length,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] PROCESS = 2'd1;
    localparam [1:0] FINISH  = 2'd2;
    
    reg [1:0] state, next_state;
    reg [3:0] current_index;
    reg [3:0] output_index;
    reg [7:0] current_char;
    reg [7:0] latched_string [0:15];
    reg [3:0] latched_length;
    reg [3:0] cycle_count;
    localparam [3:0] MAX_CYCLES = 4'd20;

    // Latch input on start
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_index <= 4'd0;
            output_index <= 4'd0;
            current_char <= 8'd0;
            output_length <= 4'd0;
            done <= 1'b0;
            cycle_count <= 4'd0;
            
            // Initialize output tuple
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                output_tuple[i] <= 8'd0;
            end
            
            // Initialize latched string
            for (i = 0; i < 16; i = i + 1) begin
                latched_string[i] <= 8'd0;
            end
            latched_length <= 4'd0;
        end else begin
            // Latch input on start pulse
            if (start && state == IDLE) begin
                integer i;
                for (i = 0; i < 16; i = i + 1) begin
                    latched_string[i] <= input_string[i];
                end
                latched_length <= input_length;
            end
            
            // State machine
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 4'd0;
                    if (start) begin
                        state <= PROCESS;
                        current_index <= 4'd0;
                        output_index <= 4'd0;
                    end
                end
                
                PROCESS: begin
                    cycle_count <= cycle_count + 4'd1;
                    current_char <= latched_string[current_index];
                    
                    // Check if character is not whitespace
                    if (current_char != 8'h20 && current_char != 8'h09 && current_char != 8'h0A) begin
                        output_tuple[output_index] <= current_char;
                        output_index <= output_index + 4'd1;
                    end
                    
                    // Move to next character
                    current_index <= current_index + 4'd1;
                    
                    // Check if processing is complete
                    if (current_index >= latched_length || cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    output_length <= output_index;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

    // Next state logic (combinational)
    always @(*) begin
        next_state = state;
        case (state)
            IDLE:    next_state = start ? PROCESS : IDLE;
            PROCESS: next_state = (current_index >= latched_length || cycle_count >= MAX_CYCLES) ? FINISH : PROCESS;
            FINISH:  next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

endmodule