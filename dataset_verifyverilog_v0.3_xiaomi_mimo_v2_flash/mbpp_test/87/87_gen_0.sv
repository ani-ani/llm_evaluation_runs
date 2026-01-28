module merge_three_dictionaries (
    input wire clk,
    input wire rst_n,
    input wire start,
    
    // Dictionary 1 inputs
    input wire [7:0] dict1_valid,
    input wire [7:0] dict1_keys [0:7],
    input wire [7:0] dict1_vals [0:7],
    
    // Dictionary 2 inputs
    input wire [7:0] dict2_valid,
    input wire [7:0] dict2_keys [0:7],
    input wire [7:0] dict2_vals [0:7],
    
    // Dictionary 3 inputs
    input wire [7:0] dict3_valid,
    input wire [7:0] dict3_keys [0:7],
    input wire [7:0] dict3_vals [0:7],
    
    // Merged dictionary outputs
    output reg [7:0] out_keys [0:7],
    output reg [7:0] out_vals [0:7],
    output reg [2:0] out_count,
    output reg overflow,
    
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] PROCESS_DICT1 = 3'd1;
    localparam [2:0] PROCESS_DICT2 = 3'd2;
    localparam [2:0] PROCESS_DICT3 = 3'd3;
    localparam [2:0] PACK_RESULTS = 3'd4;
    localparam [2:0] DONE_STATE = 3'd5;
    
    // Internal registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [3:0] counter;  // 0-8 for iterating through dict entries
    reg [7:0] temp_keys [0:7];
    reg [7:0] temp_vals [0:7];
    reg [7:0] temp_valid;
    reg [2:0] out_count_temp;
    reg [3:0] temp_index;  // For packing
    reg [3:0] pack_index;  // For packing
    reg [7:0] temp_key_to_check;
    reg [7:0] temp_val_to_add;
    reg found_match;
    
    integer i;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            out_count <= 3'd0;
            overflow <= 1'b0;
            temp_valid <= 8'h00;
            counter <= 4'd0;
            temp_index <= 4'd0;
            pack_index <= 4'd0;
            found_match <= 1'b0;
            temp_key_to_check <= 8'h00;
            temp_val_to_add <= 8'h00;
            for (i = 0; i < 8; i = i + 1) begin
                temp_keys[i] <= 8'h00;
                temp_vals[i] <= 8'h00;
                out_keys[i] <= 8'h00;
                out_vals[i] <= 8'h00;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    overflow <= 1'b0;
                    counter <= 4'd0;
                    temp_valid <= 8'h00;
                    if (start) begin
                        for (i = 0; i < 8; i = i + 1) begin
                            temp_keys[i] <= 8'h00;
                            temp_vals[i] <= 8'h00;
                        end
                    end
                end
                
                PROCESS_DICT1: begin
                    if (counter < 8) begin
                        if (dict1_valid[counter]) begin
                            // Simple add to temp array at current index
                            temp_keys[counter] <= dict1_keys[counter];
                            temp_vals[counter] <= dict1_vals[counter];
                            temp_valid[counter] <= 1'b1;
                        end
                        counter <= counter + 4'd1;
                    end
                end
                
                PROCESS_DICT2: begin
                    if (counter < 8) begin
                        if (dict2_valid[counter]) begin
                            temp_key_to_check <= dict2_keys[counter];
                            temp_val_to_add <= dict2_vals[counter];
                            // Check for match in existing temp entries
                            found_match <= 1'b0;
                            for (i = 0; i < 8; i = i + 1) begin
                                if (temp_valid[i] && temp_keys[i] == dict2_keys[counter]) begin
                                    temp_vals[i] <= dict2_vals[counter];
                                    found_match <= 1'b1;
                                end
                            end
                        end
                        counter <= counter + 4'd1;
                    end
                end
                
                PROCESS_DICT3: begin
                    if (counter < 8) begin
                        if (dict3_valid[counter]) begin
                            temp_key_to_check <= dict3_keys[counter];
                            temp_val_to_add <= dict3_vals[counter];
                            // Always override if key exists
                            found_match <= 1'b0;
                            for (i = 0; i < 8; i = i + 1) begin
                                if (temp_valid[i] && temp_keys[i] == dict3_keys[counter]) begin
                                    temp_vals[i] <= dict3_vals[counter];
                                    found_match <= 1'b1;
                                end
                            end
                        end
                        counter <= counter + 4'd1;
                    end
                end
                
                PACK_RESULTS: begin
                    // Pack temp arrays into output arrays
                    if (temp_index < 8) begin
                        if (temp_valid[temp_index]) begin
                            out_keys[pack_index] <= temp_keys[temp_index];
                            out_vals[pack_index] <= temp_vals[temp_index];
                            pack_index <= pack_index + 4'd1;
                        end
                        temp_index <= temp_index + 4'd1;
                    end
                end
                
                DONE_STATE: begin
                    out_count <= pack_index[2:0];
                    if (pack_index > 8) begin
                        overflow <= 1'b1;
                    end
                    done <= 1'b1;
                    pack_index <= 4'd0;
                    temp_index <= 4'd0;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) next_state = PROCESS_DICT1;
                else next_state = IDLE;
            end
            
            PROCESS_DICT1: begin
                if (counter >= 8) next_state = PROCESS_DICT2;
                else next_state = PROCESS_DICT1;
            end
            
            PROCESS_DICT2: begin
                if (counter >= 8) begin
                    next_state = PROCESS_DICT3;
                end else next_state = PROCESS_DICT2;
            end
            
            PROCESS_DICT3: begin
                if (counter >= 8) next_state = PACK_RESULTS;
                else next_state = PROCESS_DICT3;
            end
            
            PACK_RESULTS: begin
                if (temp_index >= 8) next_state = DONE_STATE;
                else next_state = PACK_RESULTS;
            end
            
            DONE_STATE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

endmodule