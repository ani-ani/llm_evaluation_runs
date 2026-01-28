module compare_one(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire type_a,
    input wire type_b,
    input wire [15:0] val_a,
    input wire [15:0] val_b,
    input wire [7:0] str_a,
    input wire [7:0] str_b,
    output reg [15:0] result_val,
    output reg result_type,
    output reg valid
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] PARSE = 3'd1;
    localparam [2:0] COMPARE = 3'd2;
    localparam [2:0] OUTPUT = 3'd3;
    
    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd10;

    // Internal registers for parsed values
    reg signed [15:0] parsed_a;
    reg signed [15:0] parsed_b;

    // String parsing logic
    wire [15:0] str_a_parsed;
    wire [15:0] str_b_parsed;

    assign str_a_parsed = parse_string(str_a);
    assign str_b_parsed = parse_string(str_b);

    function [15:0] parse_string(input [7:0] str);
        reg [15:0] result;
        reg [7:0] i;
        reg [3:0] integer_part;
        reg [3:0] fractional_part;
        reg comma_found;
        
        begin
            result = 16'd0;
            integer_part = 4'd0;
            fractional_part = 4'd0;
            comma_found = 1'b0;
            
            for (i = 0; i < 8; i = i + 1) begin
                if (str[i] == 8'd44) begin  // Comma ASCII value
                    comma_found = 1'b1;
                end else if (!comma_found && str[i] >= 8'd48 && str[i] <= 8'd57) begin
                    integer_part = integer_part * 4'd10 + (str[i] - 8'd48);
                end else if (comma_found && str[i] >= 8'd48 && str[i] <= 8'd57) begin
                    fractional_part = fractional_part * 4'd10 + (str[i] - 8'd48);
                end
            end
            
            result = {8'd0, integer_part} + {8'd0, fractional_part};
        end
    endfunction

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_val <= 16'd0;
            result_type <= 1'b0;
            valid <= 1'b0;
            cycle_count <= 8'd0;
            parsed_a <= 16'd0;
            parsed_b <= 16'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    valid <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state = PARSE;
                    end else begin
                        next_state = IDLE;
                    end
                end
                
                PARSE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Parse inputs based on type
                    if (type_a) begin
                        parsed_a <= str_a_parsed;
                    end else begin
                        parsed_a <= val_a;
                    end
                    
                    if (type_b) begin
                        parsed_b <= str_b_parsed;
                    end else begin
                        parsed_b <= val_b;
                    end
                    
                    next_state = COMPARE;
                end
                
                COMPARE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Compare parsed values
                    if (parsed_a == parsed_b) begin
                        result_val <= 16'd0;
                        result_type <= 1'b0;
                        valid <= 1'b1;
                        next_state = IDLE;
                    end else if (parsed_a > parsed_b) begin
                        if (type_a) begin
                            result_val <= 16'd0;  // String index not used, set to 0
                            result_type <= 1'b1;
                        end else begin
                            result_val <= val_a;
                            result_type <= 1'b0;
                        end
                        valid <= 1'b1;
                        next_state = OUTPUT;
                    end else begin
                        if (type_b) begin
                            result_val <= 16'd0;  // String index not used, set to 0
                            result_type <= 1'b1;
                        end else begin
                            result_val <= val_b;
                            result_type <= 1'b0;
                        end
                        valid <= 1'b1;
                        next_state = OUTPUT;
                    end
                end
                
                OUTPUT: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state = IDLE;
                    end else begin
                        next_state = OUTPUT;
                    end
                end
                
                default: next_state = IDLE;
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: next_state = IDLE;
            PARSE: next_state = COMPARE;
            COMPARE: next_state = OUTPUT;
            OUTPUT: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

endmodule