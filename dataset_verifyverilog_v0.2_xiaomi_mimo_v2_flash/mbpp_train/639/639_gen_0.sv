module name_filter_sum (
    input clk,
    input rst_n,
    input start,
    input [7:0] char_data,
    input valid_char,
    output reg [2:0] name_addr,
    output reg [2:0] char_addr,
    output reg fetch_next,
    output reg [7:0] result,
    output reg done,
    output reg error
);

    // State Encoding
    localparam IDLE         = 4'b0000;
    localparam FETCH_NAME   = 4'b0001;
    localparam FETCH_CHAR   = 4'b0010;
    localparam VALIDATE     = 4'b0011;
    localparam COUNT_LENGTH = 4'b0100;
    localparam ADD_TO_SUM   = 4'b0101;
    localparam NEXT_NAME    = 4'b0110;
    localparam DONE         = 4'b0111;
    localparam ERROR_STATE  = 4'b1000;

    reg [3:0] current_state, next_state;
    
    // Internal registers
    reg [2:0] name_idx;      // 0 to 7
    reg [2:0] char_idx;      // 0 to 7
    reg [7:0] temp_length;   // Length of current valid name
    
    // Combinational signals
    wire is_upper;
    wire is_lower;
    wire is_null;
    wire char_valid;
    
    // Character validation logic
    assign is_upper = (char_data >= 8'h41) && (char_data <= 8'h5A);
    assign is_lower = (char_data >= 8'h61) && (char_data <= 8'h7A);
    assign is_null  = (char_data == 8'h00);
    
    // State Transition Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end
    
    // Next State Logic
    always @(*) begin
        case (current_state)
            IDLE: begin
                if (start)
                    next_state = FETCH_NAME;
                else
                    next_state = IDLE;
            end
            
            FETCH_NAME: begin
                next_state = FETCH_CHAR;
            end
            
            FETCH_CHAR: begin
                if (valid_char)
                    next_state = VALIDATE;
                else
                    next_state = FETCH_CHAR;
            end
            
            VALIDATE: begin
                if (name_idx == 0 && char_idx == 0) begin
                    // First character of name: must be uppercase or null
                    if (is_upper || is_null) begin
                        next_state = COUNT_LENGTH;
                    end else begin
                        next_state = ERROR_STATE;
                    end
                end else begin
                    // Subsequent characters: must be lowercase or null
                    if (is_lower || is_null) begin
                        next_state = COUNT_LENGTH;
                    end else begin
                        next_state = ERROR_STATE;
                    end
                end
            end
            
            COUNT_LENGTH: begin
                // If null, check if we processed all chars for current name
                if (is_null) begin
                    // If we just found null at first char, length is 0, skip adding
                    if (char_idx == 0) begin
                        next_state = NEXT_NAME;
                    end else begin
                        next_state = ADD_TO_SUM;
                    end
                end else begin
                    // Valid char, check if more chars to fetch
                    if (char_idx == 3'b111) begin // Last char (7)
                        next_state = ADD_TO_SUM;
                    end else begin
                        next_state = FETCH_CHAR;
                    end
                end
            end
            
            ADD_TO_SUM: begin
                next_state = NEXT_NAME;
            end
            
            NEXT_NAME: begin
                if (name_idx == 3'b111) begin // Last name processed
                    next_state = DONE;
                end else begin
                    next_state = FETCH_NAME;
                end
            end
            
            DONE: begin
                next_state = DONE;
            end
            
            ERROR_STATE: begin
                next_state = ERROR_STATE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // Output Logic (Sequential)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            name_addr   <= 3'b000;
            char_addr   <= 3'b000;
            fetch_next  <= 1'b0;
            result      <= 8'h00;
            done        <= 1'b0;
            error       <= 1'b0;
            name_idx    <= 3'b000;
            char_idx    <= 3'b000;
            temp_length <= 8'h00;
        end else begin
            case (current_state)
                IDLE: begin
                    fetch_next <= 1'b0;
                    done       <= 1'b0;
                    error      <= 1'b0;
                    result     <= 8'h00;
                    name_idx   <= 3'b000;
                    char_idx   <= 3'b000;
                    temp_length <= 8'h00;
                    name_addr  <= 3'b000;
                    char_addr  <= 3'b000;
                end
                
                FETCH_NAME: begin
                    name_addr <= name_idx;
                    char_idx  <= 3'b000;
                    char_addr <= 3'b000;
                    temp_length <= 8'h00;
                    fetch_next <= 1'b1; // Request first char
                end
                
                FETCH_CHAR: begin
                    fetch_next <= 1'b0; // Reset request
                    char_addr <= char_idx;
                end
                
                VALIDATE: begin
                    // Wait here to let validation logic settle
                end
                
                COUNT_LENGTH: begin
                    // Increment length if not null char
                    if (!is_null) begin
                        temp_length <= temp_length + 8'h01;
                    end
                    
                    // Increment char index for next fetch
                    if (!is_null && char_idx != 3'b111) begin
                        char_idx <= char_idx + 3'b001;
                        char_addr <= char_idx + 3'b001;
                        fetch_next <= 1'b1; // Request next char
                    end
                end
                
                ADD_TO_SUM: begin
                    result <= result + temp_length;
                end
                
                NEXT_NAME: begin
                    name_idx <= name_idx + 3'b001;
                    name_addr <= name_idx + 3'b001;
                end
                
                DONE: begin
                    done <= 1'b1;
                end
                
                ERROR_STATE: begin
                    error <= 1'b1;
                    done  <= 1'b1;
                end
                
                default: begin
                    name_addr   <= 3'b000;
                    char_addr   <= 3'b000;
                    fetch_next  <= 1'b0;
                    result      <= 8'h00;
                    done        <= 1'b0;
                    error       <= 1'b0;
                end
            endcase
        end
    end

endmodule