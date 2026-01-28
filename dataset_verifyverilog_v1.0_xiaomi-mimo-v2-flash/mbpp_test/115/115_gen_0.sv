module dict_checker (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [63:0] list_data,
    input wire [1:0] num_dicts,
    output reg result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESSING = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    reg [1:0] state;
    reg [1:0] next_state;
    reg [1:0] dict_index;
    reg [1:0] max_index;
    reg all_empty;
    reg processing_complete;

    // Combinational logic for next state and outputs
    always @(*) begin
        // Default values
        next_state = state;
        processing_complete = 1'b0;

        case (state)
            IDLE: begin
                if (start) begin
                    next_state = PROCESSING;
                end
            end
            
            PROCESSING: begin
                // Check if we've processed all required dictionaries
                if (dict_index >= max_index) begin
                    processing_complete = 1'b1;
                    next_state = DONE_STATE;
                end
            end
            
            DONE_STATE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            dict_index <= 2'd0;
            max_index <= 2'd0;
            all_empty <= 1'b1;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    dict_index <= 2'd0;
                    all_empty <= 1'b1;
                    
                    if (start) begin
                        // Determine max_index based on num_dicts
                        // num_dicts values: 0,1,2,3 map to 0,1,2,3
                        max_index <= num_dicts;
                    end
                end
                
                PROCESSING: begin
                    // Check current dictionary (16-bit chunks)
                    // Dictionary 0: list_data[15:0]
                    // Dictionary 1: list_data[31:16]
                    // Dictionary 2: list_data[47:32]
                    // Dictionary 3: list_data[63:48]
                    
                    case (dict_index)
                        2'd0: begin
                            if (list_data[15:0] != 16'd0) begin
                                all_empty <= 1'b0;
                            end
                        end
                        2'd1: begin
                            if (list_data[31:16] != 16'd0) begin
                                all_empty <= 1'b0;
                            end
                        end
                        2'd2: begin
                            if (list_data[47:32] != 16'd0) begin
                                all_empty <= 1'b0;
                            end
                        end
                        2'd3: begin
                            if (list_data[63:48] != 16'd0) begin
                                all_empty <= 1'b0;
                            end
                        end
                        default: begin
                            all_empty <= all_empty;
                        end
                    endcase
                    
                    // Increment dict_index if not done
                    if (dict_index < max_index) begin
                        dict_index <= dict_index + 2'd1;
                    end
                end
                
                DONE_STATE: begin
                    result <= all_empty;
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                    result <= 1'b0;
                    done <= 1'b0;
                    dict_index <= 2'd0;
                    max_index <= 2'd0;
                    all_empty <= 1'b1;
                end
            endcase
        end
    end

endmodule