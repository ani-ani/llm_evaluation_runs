module remove_whitespace (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] input_str [0:15],
    input wire [3:0] valid_len,
    output reg [7:0] output_str [0:15],
    output reg [3:0] output_len,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESSING = 2'd1;
    localparam [1:0] DONE = 2'd2;
    
    // Internal registers
    reg [1:0] state;
    reg [1:0] next_state;
    reg [3:0] read_idx;
    reg [3:0] write_idx;
    reg [7:0] input_buffer [0:15];
    reg [7:0] temp_char;
    reg is_whitespace;
    
    // Whitespace constants
    localparam [7:0] SPACE = 8'h20;
    localparam [7:0] TAB = 8'h09;
    localparam [7:0] NEWLINE = 8'h0A;
    localparam [7:0] CARRIAGE_RETURN = 8'h0D;

    // Combinational whitespace check
    always @(*) begin
        is_whitespace = (temp_char == SPACE) || 
                        (temp_char == TAB) || 
                        (temp_char == NEWLINE) || 
                        (temp_char == CARRIAGE_RETURN);
    end

    // State transition logic
    always @(*) begin
        case (state)
            IDLE: next_state = start ? PROCESSING : IDLE;
            PROCESSING: begin
                if (read_idx >= valid_len) begin
                    next_state = DONE;
                end else begin
                    next_state = PROCESSING;
                end
            end
            DONE: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            read_idx <= 4'd0;
            write_idx <= 4'd0;
            output_len <= 4'd0;
            done <= 1'b0;
            temp_char <= 8'd0;
            for (i = 0; i < 16; i = i + 1) begin
                input_buffer[i] <= 8'd0;
                output_str[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Copy input to internal buffer
                        for (i = 0; i < 16; i = i + 1) begin
                            if (i < valid_len) begin
                                input_buffer[i] <= input_str[i];
                            end else begin
                                input_buffer[i] <= 8'd0;
                            end
                        end
                        read_idx <= 4'd0;
                        write_idx <= 4'd0;
                        output_len <= 4'd0;
                    end
                end
                
                PROCESSING: begin
                    if (read_idx < valid_len) begin
                        temp_char <= input_buffer[read_idx];
                        
                        // Check if character is whitespace
                        if (!is_whitespace) begin
                            output_str[write_idx] <= temp_char;
                            write_idx <= write_idx + 4'd1;
                            output_len <= output_len + 4'd1;
                        end
                        
                        read_idx <= read_idx + 4'd1;
                    end
                end
                
                DONE: begin
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                    read_idx <= 4'd0;
                    write_idx <= 4'd0;
                    output_len <= 4'd0;
                    done <= 1'b0;
                end
            endcase
            
            state <= next_state;
        end
    end

endmodule