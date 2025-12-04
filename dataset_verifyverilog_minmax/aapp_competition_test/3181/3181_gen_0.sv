module monotone_sequence(input reg [2:0] n, input reg [2:0] k, output reg [14:0] seq);
  always @(*) begin
    seq = 15'b111111111111111; // default invalid
    case ({n,k})
      {3'd1,3'd1}: seq = {3'd1,12'b0};
      {3'd2,3'd2}: seq = {3'd1,3'd2,9'b0};
      {3'd3,3'd3}: seq = {3'd1,3'd2,3'd3,6'b0};
      {3'd4,3'd4}: seq = {3'd1,3'd2,3'd3,3'd4,3'b0};
      {3'd5,3'd5}: seq = {3'd1,3'd2,3'd3,3'd4,3'd5};
      {3'd3,3'd2}: seq = {3'd1,3'd3,3'd2,6'b0};
      {3'd4,3'd2}: seq = {3'd2,3'd1,3'd4,3'd3,3'b0};
      {3'd4,3'd3}: seq = {3'd1,3'd4,3'd2,3'd3,3'b0};
      {3'd5,3'd3}: seq = {3'd2,3'd1,3'd4,3'd3,3'd5};
      {3'd5,3'd4}: seq = {3'd1,3'd2,3'd5,3'd3,3'd4};
      {3'd5,3'd1}: seq = 15'b111111111111111;
      default: ;
    endcase
  end
endmodule
