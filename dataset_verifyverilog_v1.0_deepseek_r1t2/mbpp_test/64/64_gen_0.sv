module SortTuplesByScore #(
    parameter NUM_ELEMENTS = 4,
    parameter DATA_WIDTH = 16,
    parameter NAME_WIDTH = 8
) (
    input wire clk,
    input wire rst_n,
    input wire start,
    
    input wire [NAME_WIDTH-1:0] in_name_0,
    input wire [DATA_WIDTH-1:0] in_score_0,
    input wire [NAME_WIDTH-1:0] in_name_1,
    input wire [DATA_WIDTH-1:0] in_score_1,
    input wire [NAME_WIDTH-1:0] in_name_2,
    input wire [DATA_WIDTH-1:0] in_score_2,
    input wire [NAME_WIDTH-1:0] in_name_3,
    input wire [DATA_WIDTH-1:0] in_score_3,
    
    output reg [NAME_WIDTH-1:0] out_name_0,
    output reg [DATA_WIDTH-1:0] out_score_0,
    output reg [NAME_WIDTH-1:0] out_name_1,
    output reg [DATA_WIDTH-1:0] out_score_1,
    output reg [NAME_WIDTH-1:0] out_name_2,
    output reg [DATA_WIDTH-1:0] out_score_2,
    output reg [NAME_WIDTH-1:0] out_name_3,
    output reg [DATA_WIDTH-1:0] out_score_3,
    
    output reg done
);

    localparam [2:0] STATE_IDLE = 3'd0;
    localparam [2:0] STATE_LOAD = 3'd1;
    localparam [2:0] STATE_SORT1 = 3'd2;
    localparam [2:0] STATE_SORT2 = 3'd3;
    localparam [2:0] STATE_SORT3 = 3'd4;
    localparam [2:0] STATE_DONE = 3'd5;
    
    reg [2:0] state;
    
    reg [NAME_WIDTH-1:0] names [0:3];
    reg [DATA_WIDTH-1:0] scores [0:3];
    
    wire comp_0 = (scores[0] > scores[1]);
    wire comp_1 = (scores[1] > scores[2]);
    wire comp_2 = (scores[2] > scores[3]);
    
    integer i;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= STATE_IDLE;
            done <= 1'b0;
            
            for (i=0; i<4; i=i+1) begin
                names[i] <= {NAME_WIDTH{1'b0}};
                scores[i] <= {DATA_WIDTH{1'b0}};
            end
            
            out_name_0 <= 0;
            out_name_1 <= 0;
            out_name_2 <= 0;
            out_name_3 <= 0;
            out_score_0 <= 0;
            out_score_1 <= 0;
            out_score_2 <= 0;
            out_score_3 <= 0;
        end
        else begin
            case (state)
                STATE_IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= STATE_LOAD;
                    end
                end
                
                STATE_LOAD: begin
                    names[0] <= in_name_0;
                    names[1] <= in_name_1;
                    names[2] <= in_name_2;
                    names[3] <= in_name_3;
                    scores[0] <= in_score_0;
                    scores[1] <= in_score_1;
                    scores[2] <= in_score_2;
                    scores[3] <= in_score_3;
                    state <= STATE_SORT1;
                end
                
                STATE_SORT1: begin
                    // Pass 1 - sort
                    if (comp_0) begin
                        names[0] <= names[1];
                        names[1] <= names[0];
                        scores[0] <= scores[1];
                        scores[1] <= scores[0];
                    end
                    
                    if (comp_1) begin
                        names[1] <= names[2];
                        names[2] <= names[1];
                        scores[1] <= scores[2];
                        scores[2] <= scores[1];
                    end
                    
                    if (comp_2) begin
                        names[2] <= names[3];
                        names[3] <= names[2];
                        scores[2] <= scores[3];
                        scores[3] <= scores[2];
                    end
                    state <= STATE_SORT2;
                end
                
                STATE_SORT2: begin
                    // Pass 2 - sort
                    if (comp_0) begin
                        names[0] <= names[1];
                        names[1] <= names[0];
                        scores[0] <= scores[1];
                        scores[1] <= scores[0];
                    end
                    
                    if (comp_1) begin
                        names[1] <= names[2];
                        names[2] <= names[1];
                        scores[1] <= scores[2];
                        scores[2] <= scores[1];
                    end
                    
                    if (comp_2) begin
                        names[2] <= names[3];
                        names[3] <= names[2];
                        scores[2] <= scores[3];
                        scores[3] <= scores[2];
                    end
                    state <= STATE_SORT3;
                end
                
                STATE_SORT3: begin
                    // Pass 3 - final sort & output
                    if (comp_0) begin
                        names[0] <= names[1];
                        names[1] <= names[0];
                        scores[0] <= scores[1];
                        scores[1] <= scores[0];
                    end
                    
                    if (comp_1) begin
                        names[1] <= names[2];
                        names[2] <= names[1];
                        scores[1] <= scores[2];
                        scores[2] <= scores[1];
                    end
                    
                    if (comp_2) begin
                        names[2] <= names[3];
                        names[3] <= names[2];
                        scores[2] <= scores[3];
                        scores[3] <= scores[2];
                    end
                    
                    out_name_0 <= names[0];
                    out_name_1 <= names[1];
                    out_name_2 <= names[2];
                    out_name_3 <= names[3];
                    
                    out_score_0 <= scores[0];
                    out_score_1 <= scores[1];
                    out_score_2 <= scores[2];
                    out_score_3 <= scores[3];
                    
                    state <= STATE_DONE;
                end
                
                STATE_DONE: begin
                    done <= 1'b1;
                    state <= STATE_IDLE;
                end
                
                default: state <= STATE_IDLE;
            endcase
        end
    end
endmodule