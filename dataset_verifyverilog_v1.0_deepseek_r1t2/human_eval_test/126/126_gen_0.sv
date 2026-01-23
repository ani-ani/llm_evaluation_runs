module is_sorted(
    input [7:0] arr [0:7],
    output reg result
);
    wire [3:0] K;
    assign K = (arr[7] != 8'd0) ? 4'd8 :
               (arr[6] != 8'd0) ? 4'd7 :
               (arr[5] != 8'd0) ? 4'd6 :
               (arr[4] != 8'd0) ? 4'd5 :
               (arr[3] != 8'd0) ? 4'd4 :
               (arr[2] != 8'd0) ? 4'd3 :
               (arr[1] != 8'd0) ? 4'd2 :
               (arr[0] != 8'd0) ? 4'd1 :
               4'd0;

    always @(*) begin
        case (K)
            4'd0: result = 1'b1;
            4'd1: result = 1'b1;
            4'd2: result = (arr[0] <= arr[1]);
            4'd3: result = (arr[0] <= arr[1]) && (arr[1] <= arr[2]) && (arr[0] != arr[2]);
            4'd4: result = (arr[0] <= arr[1]) && (arr[1] <= arr[2]) && (arr[2] <= arr[3]) &&
                          (arr[0] != arr[2]) && (arr[1] != arr[3]);
            4'd5: result = (arr[0] <= arr[1]) && (arr[1] <= arr[2]) && (arr[2] <= arr[3]) &&
                          (arr[3] <= arr[4]) &&
                          (arr[0] != arr[2]) && (arr[1] != arr[3]) && (arr[2] != arr[4]);
            4'd6: result = (arr[0] <= arr[1]) && (arr[1] <= arr[2]) && (arr[2] <= arr[3]) &&
                          (arr[3] <= arr[4]) && (arr[4] <= arr[5]) &&
                          (arr[0] != arr[2]) && (arr[1] != arr[3]) &&
                          (arr[2] != arr[4]) && (arr[3] != arr[5]);
            4'd7: result = (arr[0] <= arr[1]) && (arr[1] <= arr[2]) && (arr[2] <= arr[3]) &&
                          (arr[3] <= arr[4]) && (arr[4] <= arr[5]) && (arr[5] <= arr[6]) &&
                          (arr[0] != arr[2]) && (arr[1] != arr[3]) &&
                          (arr[2] != arr[4]) && (arr[3] != arr[5]) && (arr[4] != arr[6]);
            4'd8: result = (arr[0] <= arr[1]) && (arr[1] <= arr[2]) && (arr[2] <= arr[3]) &&
                          (arr[3] <= arr[4]) && (arr[4] <= arr[5]) && (arr[5] <= arr[6]) &&
                          (arr[6] <= arr[7]) &&
                          (arr[0] != arr[2]) && (arr[1] != arr[3]) && (arr[2] != arr[4]) &&
                          (arr[3] != arr[5]) && (arr[4] != arr[6]) && (arr[5] != arr[7]);
            default: result = 1'b1;
        endcase
    end
endmodule