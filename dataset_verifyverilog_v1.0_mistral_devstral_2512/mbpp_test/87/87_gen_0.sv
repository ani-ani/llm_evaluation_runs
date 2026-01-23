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

    // Internal state
    reg [2:0] state;
    reg [2:0] counter;
    reg [7:0] temp_keys [0:7];
    reg [7:0] temp_vals [0:7];
    reg [7:0] temp_valid;
    
    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] PROCESS_DICT1 = 3'd1;
    localparam [2:0] PROCESS_DICT2 = 3'd2;
    localparam [2:0] PROCESS_DICT3 = 3'd3;
    localparam [2:0] PACK_RESULTS = 3'd4;
    localparam [2:0] DONE_STATE = 3'd5;
    
    integer i, j;
    reg found;
    reg [7:0] key_to_check;
    reg [7:0] val_to_add;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            out_count <= 3'd0;
            overflow <= 1'b0;
            temp_valid <= 8'd0;
            for (i = 0; i < 8; i = i + 1) begin
                temp_keys[i] <= 8'd0;
                temp_vals[i] <= 8'd0;
                out_keys[i] <= 8'd0;
                out_vals[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= PROCESS_DICT1;
                        counter <= 3'd0;
                        temp_valid <= 8'd0;
                        for (i = 0; i < 8; i = i + 1) begin
                            temp_keys[i] <= 8'd0;
                            temp_vals[i] <= 8'd0;
                        end
                    end
                end
                
                PROCESS_DICT1: begin
                    if (counter < 3'd8) begin
                        if (dict1_valid[counter]) begin
                            temp_keys[counter] <= dict1_keys[counter];
                            temp_vals[counter] <= dict1_vals[counter];
                            temp_valid[counter] <= 1'b1;
                        end
                        counter <= counter + 3'd1;
                    end else begin
                        counter <= 3'd0;
                        state <= PROCESS_DICT2;
                    end
                end
                
                PROCESS_DICT2: begin
                    if (counter < 3'd8) begin
                        if (dict2_valid[counter]) begin
                            found <= 1'b0;
                            for (i = 0; i < 8; i = i + 1) begin
                                if (temp_valid[i] && temp_keys[i] == dict2_keys[counter]) begin
                                    temp_vals[i] <= dict2_vals[counter];
                                    found <= 1'b1;
                                end
                            end
                            if (!found) begin
                                for (i = 0; i < 8; i = i + 1) begin
                                    if (!temp_valid[i]) begin
                                        temp_keys[i] <= dict2_keys[counter];
                                        temp_vals[i] <= dict2_vals[counter];
                                        temp_valid[i] <= 1'b1;
                                        if (i >= 3'd7) overflow <= 1'b1;
                                    end
                                end
                            end
                        end
                        counter <= counter + 3'd1;
                    end else begin
                        counter <= 3'd0;
                        state <= PROCESS_DICT3;
                    end
                end
                
                PROCESS_DICT3: begin
                    if (counter < 3'd8) begin
                        if (dict3_valid[counter]) begin
                            found <= 1'b0;
                            for (i = 0; i < 8; i = i + 1) begin
                                if (temp_valid[i] && temp_keys[i] == dict3_keys[counter]) begin
                                    temp_vals[i] <= dict3_vals[counter];
                                    found <= 1'b1;
                                end
                            end
                            if (!found) begin
                                for (i = 0; i < 8; i = i + 1) begin
                                    if (!temp_valid[i]) begin
                                        temp_keys[i] <= dict3_keys[counter];
                                        temp_vals[i] <= dict3_vals[counter];
                                        temp_valid[i] <= 1'b1;
                                        if (i >= 3'd7) overflow <= 1'b1;
                                    end
                                end
                            end
                        end
                        counter <= counter + 3'd1;
                    end else begin
                        counter <= 3'd0;
                        state <= PACK_RESULTS;
                    end
                end
                
                PACK_RESULTS: begin
                    out_count <= 3'd0;
                    for (i = 0; i < 8; i = i + 1) begin
                        out_keys[i] <= 8'd0;
                        out_vals[i] <= 8'd0;
                    end
                    
                    j = 0;
                    for (i = 0; i < 8; i = i + 1) begin
                        if (temp_valid[i]) begin
                            out_keys[j] <= temp_keys[i];
                            out_vals[j] <= temp_vals[i];
                            j = j + 1;
                        end
                    end
                    out_count <= j[2:0];
                    state <= DONE_STATE;
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule